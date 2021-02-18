export default Ember.Component.extend({
  didInsertElement () {
    $('.score-amount-tip').hide()
    $(`.${this.user.custom_fields.yoyow_score_method}`).show()
    !this.isShowSetting() && $('.yoyo-settings').remove()
  },
  actions: {
    selectChange (value) {
      $('.yoyow_score_amount').val('')
      $('.score-amount-tip').hide()
      $(`.${value}`).show()
    }
  },
  isShowSetting () {
    let isShow = false
    let accounts = this.user.associated_accounts
    for (var i = 0, l = accounts.length; i < l; i++) {
      if (accounts[i].name === 'yoyow') {
        isShow = true
        break
      }
    }
    return isShow
  }
});
