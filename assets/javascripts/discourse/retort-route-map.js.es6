export default {
  resource: "user",
  path: "u/:username",
  map () {
    this.route(
      "userActivity",
      { path: "activity", resetNamespace: true },
      function () {
        this.route("yoyo-comment");
        this.route("yoyo-content");
      }
    );
    this.route(
      "preferences",
      { resetNamespace: true },
      function () {
        this.route("scores-settings");
      }
    );
  }
};
