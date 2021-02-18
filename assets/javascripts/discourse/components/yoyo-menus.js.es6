export default Ember.Component.extend({
  isShowYoyoMenu: false,
  didInsertElement () {
    let { associated_accounts } = this.user
    if (associated_accounts) {
      for (var i = 0, l = associated_accounts.length; i < l; i++) {
        if (associated_accounts[i].name === 'yoyow') {
          this.set('isShowYoyoMenu', true)
        }
      }
    } else {
      this.set('isShowYoyoMenu', false)
    }
  },
});
