import { ajax } from "discourse/lib/ajax";

export default Discourse.Route.extend({
  pagination: {
    currentPage: 1,
    limit: 10,
    offset: 0,
  },
  renderTemplate () {
    this.render("yoyo-content");
  },
  model () {
    const { user: { username_lower } } = this.modelFor("user").get("stream")

    return ajax("/yoyow_retorts/yoyow_posts.json", {
      type: "get",
      data: {
        username: username_lower,
        limit: this.pagination.limit,
        offset: this.pagination.offset
      }
    }).then(res => {
      res.rows = res.rows.map(v => Object.assign(v, {
        url: (() => {
          let url = ''
          try {
            url = JSON.parse(v.extra_data).url
          } catch (e) {
            url = 'javascript:;'
          }
          return url
        })(),
        total_score_csaf: v.total_score_csaf / 1000,
        poster_awards: v.poster_awards / Math.pow(10, 5),
        explorerUrl: `https://explorer.yoyow.org/content/${v.platform}_${v.poster}_${v.post_pid}`
      }))

      res.pagination = Object.assign(this.pagination, {
        total: res.total
      })
      return res
    })
  },
  actions: {
    changePage (type) {
      let pagination = this.pagination
      let pageCount = Math.floor(pagination.total / pagination.limit)
      if (type < 0) {
        if (pagination.currentPage > 1) {
          pagination.currentPage--
          this.refresh()
        }
      } else {
        if (pagination.currentPage < pageCount) {
          pagination.currentPage++
          this.refresh()
        }
      }
    }
  }
})
