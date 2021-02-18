import { ajax } from "discourse/lib/ajax";
import Retort from '../lib/retort'

export default Discourse.Route.extend({
  pagination: {
    currentPage: 1,
    limit: 10,
    offset: 0,
  },
  renderTemplate () {
    this.render("yoyo-comment");
  },
  model () {
    const { user: { username_lower } } = this.modelFor("user").get("stream")

    return ajax("/yoyow_retorts/yoyow_scores", {
      type: "get",
      data: {
        username: username_lower
      }
    }).then((res) => {
      res.rows = res.rows.map(v => Object.assign(v, {
        csaf: v.csaf / 1000,
        profits: v.profits / Math.pow(10, 5),
        url: (() => {
          let url = ''
          try {
            url = JSON.parse(v.post.extra_data).url
          } catch (e) {
            url = 'javascript:;'
          }
          return url
        })(),
        explorerUrl: `https://explorer.yoyow.org/content/${v.post.platform}_${v.post.poster}_${v.post.post_pid}`
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
