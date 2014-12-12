###
  Интерфейс для добавления задачи в очередь kue
  Запускается с IcedCoffeeScript
###

kue = require 'kue'
cfg = require '../../config'
redis = require 'redis'

kue.redis.createClient = ->
  client = redis.createClient()
  client.auth cfg.redis.password
  client

jobs = kue.createQueue()
reds = require('reds')
eql = require 'should/lib/eql'
require('../params')
_ = require('underscore')
async = require('async')
log = console.log.bind console

search = null
getSearch = ->
  return search if search
  reds.createClient = kue.redis.createClient;
#  reds.client = jobs.client
  return search = reds.createSearch('q:search')

#
# Проверка на дубли
# cb([result]) true если обнаружили дубль
checkDouble = (query, newJob, cb) ->
  # Ищем по title задачи
  exports.search query, (err, jobs) ->
    for job in jobs
      if eql(job?.data, newJob) and job._state not in ['complete', 'failed']
        cb true
        return
    cb false

convertParams = (nameJob, _params) ->
  _params = _.clone _params
  _params.title = "#{nameJob}: " + _params.title
  _params

#
# _jobs - массив, список задач по
exports.search = (query, cb) ->
  getSearch().query(query).end (err, ids) ->
    if err
      cb err, null # Отправляем ошибку
      return
    if ids.length is 0
      cb err, []
      return

    _jobs = []
    ids.sort().forEach (id, i) ->
      kue.Job.get id, (err, job) ->
        _jobs.push job
        cb err, _jobs if ids.length is _jobs.length


# Создание простой задачи
exports.createJob = (nameJob, params, cb) ->
  params = convertParams(nameJob, params)
  checkDouble nameJob, params, (is_checked) ->
    if is_checked
      cb new Error 'Обнаружена существующая задача'
      return

    job = jobs.create nameJob, params
    job.save cb
    #TODO: По сути вот сюда можно повесить Эвенты на "работу"
    # но я не знаю что будет с процессом подцепивщим этот интерфейс
    # он может упасть, поэтому он находится в "Менеджере"

# Создание задачи с задержкой
exports.createJobDelay = (nameJob, params, delay_sec = DELAY_JOB_AGGR, cb) ->
  params = convertParams(nameJob, params)
  checkDouble nameJob, params, (is_checked) ->
    if is_checked
      cb new Error 'Обнаружена существующая задача'
      return
    job = jobs.create nameJob, params
    job.delay(delay_sec)
    job.save cb

#
# Удалить все задачи по запросу
exports.deleteAllJobs = (query, cb) ->
  kue.redis.createClient().flushdb cb

exports.getJobById = kue.Job.get


###
  Интерфейс для добавления специфицированных задач
  Формирует протокол задач!
###

decorateTipster = (fn) ->
  (tipster, last_tips, cb) ->
    cb = last_tips if typeof last_tips is 'function'
    unless tipster
      cb new Error 'Не передан парамметр short_name типстера'
      return
    fn arguments...

# Спарсить все ставки по типстеру
# Задача уйдёт на исполнение сразу
exports.addJobParseAllTips = decorateTipster (tipster, cb=->) ->
  params =
    tipster : tipster
    title   : "Parsing all tips for #{tipster}"
  exports.createJob JOB_PARSE_ALL, params, cb

# Спарсить для всех ставок
# Задача уйдёт с задержкой
# @last_tips может быть пустым
exports.addJobParseNewTips = decorateTipster (tipster, last_tips = {}, cb=(->), delay=DELAY_JOB_AGGR) ->
  params =
    tipster : tipster
    last_tips: last_tips
    title   : "Parsing new tips for #{tipster}"
  exports.createJobDelay JOB_PARSE_NEW, params, delay, cb

##
# Аггрегировании статистики
# Задача уйдёт с задержкой
exports.addJobAggregate = decorateTipster (tipster, cb=->) ->
  params =
    tipster : tipster
    title   : "Aggregate statistics for #{tipster}"
  exports.createJobDelay JOB_STATIC_AGGR, params, DELAY_JOB_AGGR, cb

##
# fixme: в addJobAggregate можно передавать задержку, тогда этот метод отпадает
exports.addJobAggregateImmediately = decorateTipster (tipster, cb=->) ->
  params =
    tipster : tipster
    title   : "Aggregate statistics for #{tipster} MOMENT"
  exports.createJobDelay JOB_STATIC_AGGR, params, NONE_DELAY_JOB_AGGR, cb

# Отрубаемся от редис
# Хотя можно просто сделать process.exit()
exports.close = ->
  jobs.client.quit()