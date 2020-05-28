var textarea = document.getElementById('console')

var log = function () {
  console.log.apply(console, arguments)

  var args = Array.prototype.slice.call(arguments).map(function (arg) {
    if (arg instanceof Error) return `{Error: ${arg.message}}`
    else if (typeof arg === 'object' && arg) return JSON.stringify(arg)
    else return String(arg)
  })

  textarea.value += `> ${args.join(' ')}\n`
}

document.addEventListener('deviceready', function () {
  log('deviceready')

  window.cordova.plugins.IMEI(function (err, imei) {
    log(err, imei)
  })
}, false)
