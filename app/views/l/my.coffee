RootView=require 'views/core/RootView'
template=require 'templates/l/my-view'
#template = require 'templates/play/level'

module.exports = class MyView extends RootView
  id:'my-view'
  template:template
  events:
    'click #my-btn': 'onClickMButton'

  initialize:(options)->
    #初始化逻辑代码y

  onClickMButton: (e) ->
      #查找控件p
      #document.getElementById("my-l").innerHTML = 'dear a'
      @$('#my-l').text('dear a')
      console.log 'dear 你点击按钮'
