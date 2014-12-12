###

###
mongoose = require 'mongoose'
TipsDal = require '../../rest-api/app/dal/tipsDAL'
cfg = require '../../config'
Sync = require 'sync'
funcs = require '../lib/funcs'
moment = require 'moment'
parser = require '../lib/parser'


db = mongoose.createConnection cfg.mongodb.host, server: { auto_reconnect: true, poolSize: 10 }
mongoose.set 'db1', db

createLinks = ->
  $currentDate = moment()
  $startDate = moment("2013-08-01", "YYYY-MM-DD")
  $temp = (month, year) -> "http://www.goldsoccerpicks.com/records/old/?Year=#{year}&Month=#{month}"

  while $startDate < $currentDate
    link = $temp $startDate.month() + 1, $startDate.year()
    $startDate = $startDate.add 'M', 1
    link

createLinks2 = ->
  $currentDate = moment()
  $startDate = moment("2013-11-01", "YYYY-MM-DD")
  $temp = (month, year) -> "http://www.goldsoccerpicks.com/records/old/?Year=#{year}&Month=#{month}&IsGold=True"

  while $startDate < $currentDate
    link = $temp $startDate.month() + 1, $startDate.year()
    $startDate = $startDate.add 'M', 1
    link

getMatch = ($, item) ->
  item = $ item
  if item.find('td').length is 0
    return

  td = (i) ->
    item.find('td').eq(i).text()

  date_event  : moment(td(0), 'DD/MM/YYYY').toDate()
  match       : td 1
  event       : td 1 # Полное событие вместе с соревнованием
  score       : td 4
  bet         : td 3
  betOnTeam   : td 3
  odds        : (td 2).replace ',', '.'
  result      : td(5).toLowerCase()

$process = 2
end = ->
  $process--
  if $process is 0
    process.exit()


db.once 'open', ->
  console.log 'мангуст подключился! [:-]: ' + cfg.mongodb.host

  tipsDal = new TipsDal()

  Sync ->
    createLinks().forEach (link) ->
      $ = parser.sync null, link

      $('.mainTipsTable[width="700"] tr:first-child').remove()
      tips = $.map $('.mainTipsTable[width="700"] tr'), (item) ->
        funcs.trim ->
          funcs.findTeam ->
            getMatch $, item

      tips.forEach (tip) ->
        tipsDal.getAllTipsByTipster 'goldsoccerpicks', { event: new RegExp tip.event }, null, null, null, (err, docs) ->
          if docs.length > 1
            # Разрулим!
            $tips = docs.filter (doc) ->
              Math.abs(doc.date_event - new Date tips.date_event) < 3600 * 24
            if $tips.length isnt 1 # если не нашёлся один, то чтотот тут не так
              console.log 'Совпадений больше чем один! и к тому же не разрулилось' + docs[0].event
              return
          else if docs.length is 0
            console.log 'AH: Ничерта не налось совпадения для матча ' + tip.event + ' Дата: ' + 
              moment(tip.date_event).format('DD.MM.YYYY')
            return

          if tip = docs?[0]
            tip.type_section = 'AH Pick'
            tip.save (err, tip) ->
              console.log err if err

  , (err) ->
    console.log err if err
    console.log 'Паресчёт AH закончился'
    do end


  ##
  #
  Sync ->
    createLinks2().forEach (link) ->
      $ = parser.sync null, link

      $('.mainTipsTable[width="700"] tr:first-child').remove()
      tips = $.map $('.mainTipsTable[width="700"] tr'), (item) ->
        funcs.trim ->
          funcs.findTeam ->
            getMatch $, item

      tips.forEach (tip) ->
        tipsDal.getAllTipsByTipster 'goldsoccerpicks', { event: new RegExp tip.event }, null, null, null, (err, docs) ->
          if docs.length > 1
            # Разрулим!
            $tips = docs.filter (doc) ->
              Math.abs(doc.date_event - new Date tips.date_event) < 3600 * 24
            if $tips.length isnt 1 # если не нашёлся один, то чтотот тут не так
              console.log 'Совпадений больше чем один! и к тому же не разрулилось' + docs[0].event
              return
          else if docs.length is 0
            console.log 'Gold: Ничерта не налось совпадения для матча ' + tip.event
            return

          if tip = docs?[0]
            tip.type_section = 'Gold Picks'
            tip.save (err, tip) ->
              console.log err if err

  , (err) ->
    console.log err if err
    console.log 'Паресчёт Gold Picks закончился'
    do end