import { withPluginApi } from 'discourse/lib/plugin-api'
import TopicRoute from 'discourse/routes/topic'
import Retort from '../lib/retort'

function initializePlugin (api) {
  const siteSettings = api.container.lookup('site-settings:main')

  siteSettings.points_type = [
    { name: I18n.t("yoyo_settings.fixed"), value: 'fixed' },
    { name: I18n.t("yoyo_settings.ratio"), value: 'ratio' }
  ]

  TopicRoute.on("setupTopicController", function (event) {
    let controller = event.controller
    Retort.set('topicController', controller)
    controller.messageBus.subscribe(`/retort/topics/${controller.model.id}`, (data) => { Retort.callback(data) })
  })

  api.decorateWidget('post-contents:after-cooked', helper => {
    let postId = helper.getModel().id
    let post = Retort.postFor(postId)

    if (Retort.disabledFor(postId)) { return }

    Retort.storeWidget(helper)

    return _.map(post.retorts, (retort) => {
      return helper.attach('retort-toggle', {
        post: post,
        usernames: retort.usernames,
        emoji: retort.emoji
      })
    })
  })

  if (!Discourse.User.current() || !siteSettings.yoyow_enabled) { return }

  api.addPostMenuButton('retort', attrs => {
    if (Retort.disabledFor(attrs.id)) { return }
    return {
      action: 'clickRetort',
      icon: 'smile-o',
      title: 'retort.title',
      position: 'first',
      className: 'retort-scores'
    }
  })

  api.attachWidgetAction('post-menu', 'clickRetort', function () {
    const { attrs } = this
    const $target = $(`[data-post-id=${attrs.id}] .retort-scores`)
    const $position = $('.retort__emoji-picker-wrapper .ember-view')
    Retort.openPicker(this.findAncestorModel())
    $(window).off('scroll').on('scroll', function () {
      setStyle($position, $target)
    })
    setStyle($position, $target)
  })

  function setStyle ($positionDom, $referDom) {
    const $emojiBox = $('.retort__emoji-picker-wrapper .ember-view .emoji-picker')
    setTimeout(() => {
      $positionDom.css({
        position: 'absolute',
        top: $referDom.offset().top - $(window).scrollTop() - $emojiBox.height() - 10,
        left: $referDom.offset().left - $(window).scrollLeft() - $emojiBox.width() / 2 + 20
      }, 50)
    })
  }
}

export default {
  name: 'retort-button',
  initialize: function () {
    withPluginApi('0.8.6', api => {
      initializePlugin(api);
      api.modifyClass('controller:preferences/emails', {
        actions: {
          save () {
            this.get('saveAttrNames').push('custom_fields')
            this._super()
          }
        }
      })
    })
  }
}
