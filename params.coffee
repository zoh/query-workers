###
  Дополнительные парамметры, константы
###

# Спарсить все ставки для конкретного типстера
global.JOB_PARSE_ALL = 'parse all tips'

# Спарсить все ставки для всех типстеров
# TODO: Для всех оставим на потом
#global.JOB_PARSE_ALL = 'parse all tips'

# Спарсить последние ставки для конкретного типстера
global.JOB_PARSE_NEW = 'parse new tips'

# Аггрегирование статистики по типстеру
global.JOB_STATIC_AGGR = 'statistics aggregate'

# Задержка в 12 часов
# ибо 3 слишком млкий интервал
# Значение в милиСек.
global.DELAY_JOB_AGGR = 12 * 3600 * 1000

# Запускать задачи с минимальной задержкой. 30 сек.
global.NONE_DELAY_JOB_AGGR = 30 * 1000
