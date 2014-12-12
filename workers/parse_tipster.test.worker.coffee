###
  Тестовый воркер
###

kue = require('kue')
jobs = kue.createQueue()

process.on 'message', (m) ->
  if m is 'killyourself'
    process.exit()
  else if m is 'throw_error'
    throw new Error 'Просто ошибка'
  else
    process.send m

# Шлём Привет
process.send 'Start'


setTimeout (-> process.send 'Done'), 2000