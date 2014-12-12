###
  Аггрегаты алгоритмы для подсчёта статистики для типстров
  TODO: Здесь я не воспользоватлся REST_API так как решил,
  да и мне хотелось с ним повозиться
  TODO: что Aggregate Framework будет работать шустрее, посомтрим :)
###

###
  TODO: Возможно прийдётся Переписывать, чтобы не было ситуации с is_processed
  тоесть при большом числе ставок и числа "задач" Возможна ситуация когда ставки
  будут добавляться, и рассчёт будет отличаться для разных операций
  Например:
    * поступила задача на аггрегирование
    * посчитали aggreAllProfit
    * добавили новые 5 ставок в монгу
    * посчитали passabilityTips
  Тут мы видел что в расчёт aggreAllProfit не пойдут эти 5 ставок ...
###

exports = module.exports
mongoose  = require 'mongoose'
cfg = require '../../config'
Sync = require 'sync'
__ = require 'underscore'
moment = require 'moment'

mongoose.set 'db1', db = mongoose.createConnection cfg.mongodb.host

db.once 'open', ->
  console.log 'Has been connected to mongodb: ' + cfg.mongodb.host

TipsDal = require('../../rest-api/app/dal/tipsDAL')
modelTips = (tipsModel = new TipsDal).getModel()

# Округляем до 2х десятичных
fixed = (_) -> +(_)?.toFixed(2)

getParamsTipster = (tipster, params = {}) ->
  tipster.date_event = moment(tipster.date_event, 'DD/MM/YY').toDate() if tipster.date_event
  __.extend tipster: tipster, suspicious: false, params


# Устанавливаем is_processed для ставок
exports.setIsProcessedTips = (tipster, cb) ->
  modelTips.update getParamsTipster(tipster), {is_processed: true}, {multi: true}, (err) ->
    cb err

# Подсчёт динамики движения профита
# С аггрегацией по дням
exports.aggreDinamicProfitByDay = (tipster, cb = (err, result) ->) ->
  mapRed =
    # scope: _: last: 0
    query: getParamsTipster tipster
    map: () ->
      clearParam = (_) ->
        _ = String _
        if _.length is 1
          '0' + _
        else if _.length is 4 # Типа год, нам нужно 2 последние цифры
          _.slice 2
        else
          _
      date = new Date this.date_event
      emit "#{clearParam date.getDate()}/#{clearParam date.getMonth() + 1}/#{clearParam date.getFullYear()}", this.profit
    reduce: (key, values) ->
      Array.sum(values)
    # Тут поймал прикол, если мы будем писать _last, тогда у нас просто сосздастся
    # переменная в пространстве  всё
    # finalize: (key, reducedValue) ->
      # _.last = _.last + reducedValue
      # return +_.last.toFixed(2)

  modelTips.mapReduce mapRed, (err, result) ->
    result = result.sort (a, b) ->
      if moment(a._id, ['DD/MM/YY']) > moment(b._id, ['DD/MM/YY'])
        1
      else 
        -1
    sum = 0
    result.forEach (item) ->
      sum += item.value
      item.value = fixed sum
    cb err, result

# Подсчёт динамики движения профита
# Только по чистым ставкам, без аггрегирования
exports.aggreDinamicProfitByTips = (tipster, cb) ->
  modelTips.find(getParamsTipster(tipster), 'profit')
    .sort('date_event date_add')
    .exec (err, tips) ->
      _ = 0
      cb err, tips?.map (item, i) ->
        _id: i
        value: fixed _ += item.profit

# Подсчитать полностью сумму профита
exports.aggreAllProfit = (tipster, cb) ->
  modelTips.aggregate(
    {$match: getParamsTipster tipster}
    {$group: _id: null, allProfit: $sum: '$profit'}
  , (err, result) ->
      cb err, fixed result?[0]?.allProfit
  )

# Проходимость в %
exports.passabilityTips = (tipster, cb) ->
  getCount = (params, cb) ->
    modelTips.count params, cb
  Sync ->
    allTips = getCount.sync null, getParamsTipster(tipster)
    allWinTips = getCount.sync null, getParamsTipster(tipster, result: 'win')
    fixed allWinTips / allTips * 100
  , cb

exports.getAllCount = (tipster, cb) ->
  modelTips.count getParamsTipster(tipster), cb

# Процент реинвестирования в %
# Это сумма прибыли ко всем ставкам
exports.calculateRoi = (tipster, cb) ->
  modelTips.aggregate(
    {$match: getParamsTipster(tipster)}
    {$group: _id: null, allAmount: $sum: '$unit'}
  ,
    (err, res) ->
      if err
        cb err
        return
      allAmount = res[0]?.allAmount
      exports.aggreAllProfit tipster, (err, all_profit) ->
        cb err, fixed all_profit/allAmount*100
  )

# Средний коэфицент ставок
exports.getAvarageOdds = (tipster, cb) ->
  modelTips.aggregate(
    {$match: getParamsTipster(tipster)}
    {$group: _id: null, avarageOdds: $avg: '$odds'}
  ,
    (err, res) ->
      if err
        cb err
        return
      avarageOdds = res[0]?.avarageOdds
      cb err, fixed avarageOdds
  )


# Получение максимальной просадки (фактический размер)
# p.s.
# так как на вход передаётся массив значений прибыли,
# то чтобы получить (%)ое значение нужно <полученный результат>/<BankRoll>*100%
exports.maxDrawdown = (data) ->
  currentLow = currentHigh = 0
  stack = []
  if data?.length
    for y in data
      currentHigh = y unless currentHigh?
      currentLow = y unless currentLow?
      if currentHigh < y
        stack.push currentHigh - currentLow
        currentLow = currentHigh = y
      if currentLow > y
        currentLow = y
  # Вдруг не дошли до конца
  stack.push currentHigh - currentLow
  fixed Math.max stack...


# Получение максимальной просадки (в процентах)
exports.maxDrawdownPercent = (bankRoll, data) ->
  fixed exports.maxDrawdown(data) / bankRoll * 100

# Формула подсчёта рейтинга для типстера
# У нас ROI и проходимость должны прийти были в процентах, поэтому и делим 2 раза по 100
exports.calculateRate = (allprofit, maxDrawdown, roi, passability, avarageOdds) ->
  fixed Math.abs(allprofit-maxDrawdown) / allprofit * (Math.abs roi/100) * (passability/100) * avarageOdds

##
# @tipsters_stats массив с данными
# @sorted отсортирован ли массив по рейтингу
exports.calculatedPosition = (tipsters_stats, sorted = true) ->
  unless sorted
    tipsters_stats = tipsters_stats?.sort (item, next) -> next.rate - item.rate
  tipsters_stats.forEach (item, i) ->
    item.position = i + 1
  tipsters_stats

