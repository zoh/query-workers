###
  Обёртка для удобного парсинга сайтов
###

jsdom = require("jsdom")
fs = require("fs")
jqueryStr = fs.readFileSync(__dirname + "/jquery-1.9.1.min.js").toString()

###
  Возвращает jQuery объект страницы
###
module.exports = (link, cb) ->
  jsdom.env
    html: link
    src: [jqueryStr]
    done: (errors, window) ->
      $ = window.jQuery
      cb errors, $