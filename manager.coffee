###
  Менеджер для управления воркерами
###

jobsManager = require './lib/jobs'
kue = require 'kue'
logger = require '../logger'
cfg = require '../config'
require './params'

aggregates = require './lib/aggregates'
StaticsDAL = require '../rest-api/app/dal/statisticsDAL'
Sync = require 'sync'


jobs = kue.createQueue()
express = require 'express'
jobs.promote 1000

WorkerQueue = require './lib/worker_queue'

###
  Обработчики заданий
###

##
# Создание новой задачи
createNewJob = (tipster_short_name, cb = (err, res) ->) ->
  jobsManager.addJobParseNewTips tipster_short_name, {}, (err, res) ->
    logger.logger 'Задача почему то добавилась с ошибкой: ' + err, logger.ERROR if err?
    cb err, res

##
# Алгоритм парсинга всех ставок
# TODO: Пока вообще никак не используется, нет таких алгоритмов
jobs.process JOB_PARSE_ALL, 2, (job, done) ->
  done 'Данный алгорит ещё не разработан'
  return
  tipster = job.data.tipster + '.all'
  unless tipster and WorkerQueue.existWorker(tipster)
    done 'Uncorrect tipster name for job: ' + tipster
    return

  worker = new WorkerQueue tipster
  worker.onError ->
    done new Error 'При парсинге произошла ошибка'
  worker.onSuccess ->
    done()

##
# Алгоритм парсинга новых ставок
jobs.process JOB_PARSE_NEW, 2, (job, done) ->
  tipster = job.data.tipster + '.new'
  unless tipster and WorkerQueue.existWorker(tipster)
    done 'Uncorrect tipster name for job: ' + tipster
    return
  # Передаём последнюю ставку
  worker = new WorkerQueue tipster
  worker.onError ->
    createNewJob job.data.tipster
    clearTimeout(t)
    done new Error 'При парсинге произошла ошибка'
  worker.onMessage (message) -> job.log message
  worker.onSuccess ->
    createNewJob job.data.tipster
    clearTimeout(t)
    done()
  # убиваем зависший воркер
  t = setTimeout (->
    createNewJob job.data.tipster
    worker.close()
    done 'Воркер убит по таймауту.'
  ), 15 * 60 * 1000 # 5 minutes timeOut

##
# Аггрегирование данных
staticsDAL = new StaticsDAL()
noNan = (_) ->
  null if isNaN(_)
  _
jobs.process JOB_STATIC_AGGR, 5, (job, done) ->
  tipster = job.data.tipster

  Sync ->
    dynamics_profit_daily = aggregates.aggreDinamicProfitByDay.sync null, tipster
    dynamics_profit_tips = aggregates.aggreDinamicProfitByTips.sync null, tipster
    all_profit = aggregates.aggreAllProfit.sync null, tipster
    passability_tips = aggregates.passabilityTips.sync null, tipster
    all_count = aggregates.getAllCount.sync null, tipster
    roi = aggregates.calculateRoi.sync null, tipster
    avarage_odds = noNan aggregates.getAvarageOdds.sync null, tipster

    # TODO: 2000 - тут это bankRoll его нужно вынести в отдельную перменную
    max_drawdown = aggregates.maxDrawdownPercent 2000, dynamics_profit_tips?.map (_) -> _.value
    _max_drawdown = aggregates.maxDrawdown dynamics_profit_tips?.map (_) -> _.value
    rate = noNan aggregates.calculateRate all_profit, _max_drawdown, roi, passability_tips, avarage_odds

    # TODO: хотя может убрать этот rate ?
    stats = {
      dynamics_profit_daily
      dynamics_profit_tips
      all_profit
      passability_tips
      all_count
      roi
      avarage_odds
      max_drawdown
      rate
    }

    # в подсчёт рейтинга оставляем только активных типстеров
    getTipstersStats = (cb) ->
      staticsDAL.getModel().find(is_deleted: $ne: true, 'tipster rate').sort('-rate').exec cb

    staticsDAL.updateStatistics.sync staticsDAL, tipster, stats
    tipsters_stats = getTipstersStats.sync null
    tipsters_stats = aggregates.calculatedPosition tipsters_stats
    tipsters_stats.is_processed = true;
    tipsters_stats.forEach (item) -> item.save()
  , (err) ->
    if err
      done 'Ошибка при подсчёте аггрегированной статистики ' + err.stack
      return
    done()
