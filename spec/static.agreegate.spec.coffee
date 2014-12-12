###
  Спецификация описывающая работу алгоритмы работы
  с аггрегированными данными
###


aggregates = require '../lib/aggregates'
TipsDal = require('../../rest-api/app/dal/tipsDAL')
modelTips = (tipsModel = new TipsDal).getModel()
cfg = require '../../config'
moment = require 'moment'

$checkDate = (date) -> moment(date, 'DD/MM/YY').toDate()

describe 'spec aggregate statistics tipster', ->
  testTipster = 'testTipster'
  res = err = null
  defaultUnit = cfg.tips.unit
  calProfit = (odds) ->
    +(defaultUnit * (odds - 1)).toFixed 2

  # Добавим несколько ставок
  before (done) ->
    await
      tipsModel.addTips testTipster, {date_event: $checkDate('01/11/12'), odds: '2.01', result: 'win' }, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('10/11/12'), odds: '2.01', result: 'win' }, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('10/11/12'), event: 'lol', odds: '1.71', result: 'lose'}, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('12/11/12'), odds: '2.01', result: 'draw'}, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('13/11/12'), odds: '1.85', result: 'win' }, defer()

      tipsModel.addTips testTipster, {date_event: $checkDate('01/12/12'), event: 'lol', odds: '2.01', result: 'lose'}, defer()

      tipsModel.addTips testTipster, {date_event: $checkDate('14/11/12'), odds: '2.01', result: 'win' }, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('15/11/12'), odds: '2.01', result: 'lose'}, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('02/12/12'), event: 'lol', odds: '2.01', result: 'lose'}, defer()
      tipsModel.addTips testTipster, {date_event: $checkDate('15/11/12'), event: 'lol', odds: '2.01', result: 'lose'}, defer()
    done()

  after (done) ->
    tipsModel.removeAll done

  it 'dinamic profit (aggre by days)', (done) ->
    await modelTips.count defer(err, count)
    count.should.equal 10
    await aggregates.aggreDinamicProfitByDay testTipster, defer err, res
    console.log res

    res.length.should.equal 8
    res[0].value.should.equal calProfit 2.01
    res[1].value.should.equal calProfit(2.01) + calProfit(2.01) - defaultUnit
    res[4].value.should.equal calProfit(2.01) + calProfit(2.01) - defaultUnit + 0 + calProfit(1.85) +
      calProfit(2.01)
    done()

  it 'dinamic profit (by tips)', (done) ->
    await aggregates.aggreDinamicProfitByTips testTipster, defer err, res
    console.log res
    res.length.should.equal 10
    res[0].value.should.equal calProfit 2.01
    res[4].value.should.equal 2*calProfit(2.01) - defaultUnit + 0 + calProfit(1.85)
    done()


  it 'get all count', (done) ->
    await aggregates.getAllCount testTipster, defer err, res
    res.should.equal 10
    done()

  it 'calculate all profit', (done) ->
    await aggregates.aggreAllProfit testTipster, defer err, res
    res.should.equal -112
    done()

  it 'calculated passability tips', (done) ->
    await aggregates.passabilityTips testTipster, defer err, res
    res.should.equal +(4/10*100).toFixed 2
    done()

  it 'calculated ROI', (done) ->
    await aggregates.calculateRoi testTipster, defer err, res
    res.should.equal +(-112 / (10*defaultUnit) * 100).toFixed(2)
    done()

  it 'calculate avarage tips', (done) ->
    await aggregates.getAvarageOdds testTipster, defer err, res
    res.should.equal 1.96
    done()


  # В ручную были подсчитаны и подобранны данные
  it 'calculate max drawdown', (done) ->
    aggregates.maxDrawdown([0,1,4,7,5,4,6,2,10]).should.equal 5
    aggregates.maxDrawdown(_data = [0,-100,250,100,500,200,500,-400,0]).should.equal 900
    aggregates.maxDrawdownPercent(2000,_data).should.equal 45
    aggregates.maxDrawdownPercent(2230,_data).should.equal 40.36
    await aggregates.aggreDinamicProfitByDay testTipster, defer err, res
    aggregates.maxDrawdown(res?.map (_) -> _.value).should.equal 400

    aggregates.maxDrawdown([ -100, -200, -300, -200, -300, -235.5 ]).should.equal 300
    done()


  it 'calculated rate tipster', (done) ->
    await aggregates.aggreDinamicProfitByDay testTipster, defer err, res
    maxDrawdown = aggregates.maxDrawdown(res?.map (_) -> _.value)
    await
      aggregates.aggreAllProfit testTipster, defer err, allProfit
      aggregates.calculateRoi testTipster, defer err, roi
      aggregates.passabilityTips testTipster, defer err, passability
      aggregates.getAvarageOdds testTipster, defer err, avarageOdds

    rate = aggregates.calculateRate allProfit,maxDrawdown,roi,passability,avarageOdds
    console.log "Rate: #{rate}"
    console.log allProfit,maxDrawdown,roi,passability,avarageOdds

    rate = aggregates.calculateRate -109, 10, -21.8, 40, 1.89
    console.log "Rate: #{rate}"

    done()

  it 'set is_processed tips',  (done) ->
    await aggregates.setIsProcessedTips testTipster, defer err
    await modelTips.count tipster: testTipster, is_processed: true, defer(err, count)
    count.should.equal 10
    await modelTips.count tipster: testTipster, is_processed: false, defer(err, count)
    count.should.equal 0
    done()


  it 'calculated position', ->
    data = [
      {
      id: 'sdfsdfsgdfgd'
      rate: 500
      }
      {
      id: '3v4tbv3tb45yb'
      rate: 100
      }
      {
      id: 'v4645yb4y4y'
      rate: 200
      }
    ]
    res = aggregates.calculatedPosition data, false
    res[0].should.have.property 'position', 1
    res[0].should.have.property 'rate', 500
    res[1].should.have.property 'position', 2
    res[1].should.have.property 'rate', 200
