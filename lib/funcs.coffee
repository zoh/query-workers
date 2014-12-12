diff = require 'diff'
request = require 'request'
$jquery = require("jquery")

cfg = -> require '../../config'

exports = module.exports

# Извлекаем из коэфицента "/" ставим ","
# @example '-1.5/2' -> '-1.5, -2'
exports.handicap = (fn) ->
  match = fn()
  if __ = match.handicap.match(/(.*)\/(.*)/)
    # Тут первый символ задёт знак +/-
    znak = __[1][0]
    if __[1][1] is '0' and __[1].length is 2
      __[1] = __[1].slice(1)
    if znak in ['-', '+']
      match.handicap = "#{__[1]}, #{znak}#{__[2]}"
    else
      match.handicap = "#{__[1]}, #{znak}#{__[2]}"
  match

##
# ('-1.5/2').should.equal '-1.75'
exports.handicapToSum = (handicap) ->
  if __ = handicap.match(/(.*), (.*)/)
    # Тут первый символ задёт знак +/-
    sum = ((+__[1]) + (+__[2])) / 2
    handicap = sum
  String handicap


##
# Приводит "-0.25" к "0, -0.5" для дальнейщего поиска
exports.handicapSum = (handicap) ->
  handicap = Number handicap
  znak = handicap > 0

  if handicap is Number (handicap).toFixed(1) # Рубим до 00.5
    return '0' if handicap is 0
    return (if znak then '+' else '-') + Math.abs handicap

  res = Math.abs handicap * 2
  res += .5
  y = res / 2
  x = y - .5

  if znak
    if x isnt 0
      "+#{x}, +#{y}"
    else
      "#{x}, +#{y}"
  else
    if x isnt 0
      "-#{x}, -#{y}"
    else
      "#{x}, -#{y}"


# Функция, переворачивает гандикаг
exports.reverseHandicap = (odds_str) ->
  if odds_str.match /\+/
    odds_str = odds_str.replace(/\+/g, '-')
  else if odds_str.match /\-/
    odds_str = odds_str.replace(/\-/g, '+')
  else
    odds_str


# Чистим от пробелов
exports.trim = (fn) ->
  match = fn()
  for key of match
    val = match[key]
    match[key] = (val + '').trim()
  match = exports.recoverBool -> match


# Восстанавливает булевые значения из строки
exports.recoverBool = (fn) ->
  match = fn()
  for key of match
    val = match[key]
    match[key] = false if val is 'false'
    match[key] = true if val is 'true'
  match


# Находим типстеров между "vs" или ' - ' ну или ) ' – '
exports.findTeam = (fn) ->
  match = fn()
  if __ = match.match.match(/(.*)vs(.*)/)
    match.team_home = __[1]
    match.team_away = __[2]
  else if  __ = match.match.match(/(.*) - (.*)/)
    match.team_home = __[1]
    match.team_away = __[2]
  else if  __ = match.match.match(/(.*) – (.*)/) # Тут UTF символ подчёркивания!
    match.team_home = __[1]
    match.team_away = __[2]
  match

# На какую команду ставка
# определяется наличием <b>
exports.selectOnTeam = (fn) ->
  match = fn()
  if match.team_home.match /<b>.+<\/b>/
    match.betOnWithHandicap = match.team_home + " " + match.handicap
    match.betOn = match.team_home
  else
    match.betOnWithHandicap = match.team_away + " " + match.handicap
    match.betOn = match.team_away
  match

# Убираем лишние теги
exports.clearHtmlTag = (tags = [], not_clear = []) ->
  (fn) ->
    match = fn()
    for key of match when key not in not_clear
      val = match[key]
      match[key] = val?.replace(RegExp("<[/]?(" + tags.join("|") + ")[ ]*[/]?>", "g"), "")
    match

# Сравнение команд
# c проверкой на вложенность
exports.compare = (team1, team2) ->
  team1.indexOf(team2) isnt -1 or team2.indexOf(team1) isnt -1

##
# На основе пересечении символов делает предположение о совпадении команд
# п.с. можно использовать с OR в отличии от "compare"
exports.compareDiff = (team1, team2) ->
  res = diff.diffChars team1, team2
  restrictChars = 0;
  not_restrict_add = 0
  not_restrict_removed = 0

  for i in res
    if not i.added and not i.removed
      restrictChars += i.value?.length
    not_restrict_add += i.value?.replace(' ', '').length if i.added
    not_restrict_removed += i.value?.replace(' ', '').length if i.removed
  (restrictChars / not_restrict_add > 3) or (restrictChars / not_restrict_removed > 3)

# Проверка на то, верный ли результат
# высчитан типстером
exports.validateResult = (match) ->
  handicap = match.handicap.split(',').reduce (prev, curr) -> +prev + +curr
  handicap /= 2 if match.handicap.indexOf(',') > 0

  score = match?.livescore?.score || match?.score
  if match.team_home is match.betOn
    value = eval(score) +  +handicap
  else
    value = -1 * (eval(score) - +handicap)

  switch match.result
    when 'win'
      value > 0
    when 'lose'
      value < 0
    when 'draw'
      value is 0

##
# Получение последней ставки у типстера по его short_name
# используя xAuth
exports.getLastMathTipster = (tipster_name, cb) ->
  request.post
    url: cfg().xauth.url
    json:
      client_id: cfg().xauth.client_id
      username: cfg().xauth.username
      client_secret: cfg().xauth.client_secret
      password: cfg().xauth.password
      grant_type: 'password'
  , (err, res, body) ->
    if err or !body.access_token
      cb new Error 'Токен не определён'
      return

    request.get "http://#{cfg().api_host}/api/v1.4/tipsters/#{tipster_name}/tips.json",
      {qs: access_token: body.access_token, json: {limit: 1, sort: '-date_event'}},
      (err, res, body) ->
        if body?.length
          cb err, body?[0]
        else
          cb err, null


# Добавление новой ставки к типстеру
exports.addTipsToTipster = (tipster_short_name, tips, cb) ->
  request.post
    url: cfg().xauth.url
    json:
      client_id: cfg().xauth.client_id
      username: cfg().xauth.username
      client_secret: cfg().xauth.client_secret
      password: cfg().xauth.password
      grant_type: 'password'
  , (err, res, body) ->
    if err or !body.access_token
      cb err
      return

    request.post "http://#{cfg().api_host}/api/v1.4/tipsters/#{tipster_short_name}/tips.json",
      {json: tips, qs: access_token: body.access_token},
      (error, response, body) ->
        cb error, body
        