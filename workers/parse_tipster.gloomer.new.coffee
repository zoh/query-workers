###
  Парсинг ставок от Gloomer из xml'ок
###

funcs = require '../lib/funcs'
Sync = require('sync');
parser = require '../lib/parser'

moment = require 'moment'
logger = require '../../logger'
XLS = require 'xlsjs'

exec = require('child_process').exec

# Краткое наименование тистера который он хранится в Монге
tipster_short_name = 'gloomer'

Sync ->
  # закачиваем
  exec.sync null, 'wget http://betcraft.com/2014.xls'
  xls = XLS.readFile './2014.xls'

  # переводим всё в json
  matches =  XLS.utils.sheet_to_row_object_array xls.Sheets['История ставок']

  # нужно почистить список (удалить пустые и установить всем дату)
  $prevDate = null
  matches = matches.filter (match) -> 
    match.match = match['Матч']
    match['Ставка']
  .map (match) ->
    $originDate = null
    match = funcs.findTeam -> match
    $prevDate = match['Дата'] if match?['Дата'] 
    # если нет своей даты, нужно рассчитать из педыдущей
    match['Дата'] = $originDate = $prevDate unless match['Дата']
    match['Дата'] = moment(match['Дата'] + ' 2014').toDate()
    # Если получившийся дата больше текущей, тогда явно чтото не так.
    if match['Дата'] > new Date
      match['Дата'] = moment($originDate + ' 2013').toDate()
    match
  .map (match) ->
    # win lose draw
    match.result = switch match.undefined
      when 'L'
        'lose'
      when 'W'
        'win'
      else
        'draw'
    match
  .map (match) ->
    # определяем тип ставки total, handicap ...
    match.sport = 'tennis'
    match.typeBet = if match['Ставка'].indexOf('(') > -1
        'handicap'
      else if match['Ставка'].indexOf('Б') > -1
        'total'
      else if match['Ставка'] is '1' or  match['Ставка'] is '2'
        '1X2'
    match


  matches.forEach (match) ->
    options =
      tipster: tipster_short_name
      date_event: match['Дата']
      event: match['Матч']
      team_home: match.team_home
      team_away: match.team_away
      bet: match['Ставка']
      typeBet: match.typeBet
      # betOnTeam: match.betOnWithHandicap
      odds: match['Коэф']
      # score: match.score
      result: match.result
      parseSource: additional: match.undefined
      # suspicious: match.suspicious
    if _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
      console.log _tips
      process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"
  

  # удаляем этот файл
  exec.sync null, 'rm 2014.xls*'
, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()