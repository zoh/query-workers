###
  Анализатор типа монад для мост-фантома
  с ассинхрронным механизмом
  ... кода мало, так как его восстанавивал и комменты похерил :(
###

async = require("async")


module.exports = analizator = (ph) ->
    asyncFn = []
    Page = null

    openLink: (link) ->
      asyncFn.push (callback) ->
        Page?.close?()

        unless link?
          callback new Error 'Неопределена ссылка для загрузки страницы'

        ph.createPage (page) ->
          page.open link, (status) ->
            console.log "Open page status: " + status + " #{link}"
            Page = page
            callback null, null
      @

    wait: (msec = 1000) ->
      asyncFn.push (result, callback) ->
        setTimeout (->
          callback null, result
        ), msec
      @

    # Ожидание пока не выполнится условие в функции
    waitUntil: (fn, msec = 100) ->
      asyncFn.push (result, callback) ->
        do ->
          callee = arguments.callee
          setTimeout (->
            Page.evaluate fn, (res) ->
              if res
                callback null, result
              else
                callee()
          ), msec
      @

    # Выполнение в фантоме
    nextEvaluate: (evaluateFn) ->
      asyncFn.push (result, callback) ->
        Page.evaluate evaluateFn, (result) ->
          callback null, result
      @

    next: (fn) ->
      asyncFn.push (result, callback) ->
        fn result, callback
      @

    end: (fn) ->
      async.waterfall asyncFn, (result) ->
        ph.exit()
        fn null, result

    throw: ->
      asyncFn.push (result, callback) ->
        callback "Ошибка блять"
      @