funcs = require '../lib/funcs'
Sync = require('sync');
parser = require '../lib/parser'

moment = require 'moment'
logger = require '../../logger'

# Краткое наименование тистера который он хранится в Монге
tipster_short_name = 'betmanru'

typeSport = (str) ->
  if /(Теннис|WTA|ATP)/.test str
    'tennis'
  else if str.match 'Футбол'
    'football'
  else if /(КХЛ|Хоккей)/.test str
    'hockey'
  else if str.match 'Баскетбол'
    'basketball'
  else ''

getBookie = (__) ->
  link = __.attr('src')
  if getLink = link?.match '/images/bukmeker/(.*).jpg'
    getLink?[1][0].toUpperCase() + getLink?[1][1..]

isExpess = (_) ->
  /Экспрес/.test _

[ 'http://bet-man.ru/statistika-prognozov/item/309'
  'http://bet-man.ru/statistika-prognozov/item/341'
  'http://bet-man.ru/statistika-prognozov/item/358'
].forEach (tipster_link) ->

  formatDate = (date) ->
    format = null
    if /\d{2}.\d{2}.\d{4}/.test date # если формат DD.MM.YYYY HH:mm
      format = 'DD.MM.YYYY HH:mm'
    else
      format = 'DD.MM.YY HH:mm'
    moment(date, format).toDate()

  Sync ->
    $ = parser.sync null, tipster_link

    getMatch = (item) ->
      item = $ item
      td = (i) -> item.find('td').eq(i).text()

      date_event  : formatDate td 0
      match       : td 2
      event       : "#{td 1}: #{td 2}" # Полное событие вместе с соревнованием
      sport       : typeSport td 1
      bookie      : getBookie item.find('.buk img')
      score       : td 6
      odds        : (td 4).replace ',', '.'
      result      : item.find('td').eq(6).attr('class')?.replace 'loose', 'lose'
      bet         : td 3
      # typeBet Много различных вариантов
      is_express  : isExpess td 1
      tipster     : tipster_short_name

    # Нужно отобрать таблицы, которые с платными прогнозами
    tips = $.map $('#supertable1 .stavka'), (item) -> funcs.trim -> funcs.findTeam -> getMatch item

    unless tips
      logger.logger "Почему ничего не спарсилось с #{tipster_short_name}", logger.WARNING

    tips.forEach (match) ->
      _tips = funcs.addTipsToTipster.sync null, tipster_short_name, match
      process.send? "Добавлена ставка: #{_tips?.id}  #{match.date_event} #{_tips.event} >> #{_tips.betOnTeam}"

  , (err) ->
    console.log err.stack if err
    logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

    process.send?('Done')
    process.exit()