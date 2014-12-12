###
  Класс для создания воркеров, для обработки очередей
###

fork = require('child_process').fork
fs = require 'fs'
EventEmitter = require('events').EventEmitter


class WorkerQueue

  makePath = (name) ->
    __dirname + "/../workers/parse_tipster.#{name}." + if process.env.NODE_ENV is 'test' then 'js' else 'coffee'

  @existWorker: (name) ->
    fs.existsSync makePath name

  constructor: (@path, @params = []) ->
#    if fs.existsSync @path
#      throw new Error("Не найден файл #{@path}")
    @_worker = null
    @_events = new EventEmitter
    @fork()
    @initEvent()

  fork: ->
    @_worker = fork makePath(@path), @params

  # Навешиваем воркеров
  initEvent: ->
    # Ждём когда отвалится
    @_worker.on 'close', (sigcode) =>
      console.log "Process disconect code: #{sigcode}"

    @_worker.on 'error', (err) =>
      @_events.emit 'error', err

    @_worker.on 'message', (message) =>
      if message is 'Start'
        console.log 'Воркер стартанул'
        @_events.emit 'start'
      else if message is 'Done'
        console.log 'Воркер закончил работу успешно!'
        @_events.emit 'success'
      else
        @_events.emit 'message', message

  # Успешное запуск воркера
  onStart: (listener) ->
    @_events.once 'start', listener

  # Успешное выполнение задачи
  onSuccess: (listener) ->
    @_events.on 'success', listener

  # Если вылетит ошибка
  onError: (listener) ->
    @_events.once 'error', listener

  onMessage: (listener) ->
    @_events.on 'message', listener

  # Отправка сообщения процессу
  send: (message) ->
    @_worker.send message

  getWorker: -> @_worker

  close: ->
    @getWorker().kill()

module.exports = WorkerQueue