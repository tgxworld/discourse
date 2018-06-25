import { default as computed } from "ember-addons/ember-computed-decorators";

export function Placeholder(viewName) {
  this.viewName = viewName;
}

export default Ember.Object.extend(Ember.Array, {
  posts: null,
  _appendingLength: null,

  init() {
    this._appendingLength = 0;
  },

  @computed
  length() {
    return this.get("posts.length") + this._appendingLength;
  },

  _changeArray(cb, offset, removed, inserted) {
    this.arrayContentWillChange(offset, removed, inserted);
    cb();
    this.arrayContentDidChange(offset, removed, inserted);
    this.propertyDidChange("length");
  },

  clear(cb) {
    this._changeArray(cb, 0, this.get("posts.length"), 0);
  },

  appendPost(cb) {
    this._changeArray(cb, this.get("posts.length"), 0, 1);
  },

  removePost(cb) {
    this._changeArray(cb, this.get("posts.length") - 1, 1, 0);
  },

  refreshAll(cb) {
    const length = this.get("posts.length");
    this._changeArray(cb, 0, length, length);
  },

  appending(appendingLength) {
    this._changeArray(
      () => {
        this._appendingLength = appendingLength;
      },
      this.get("length"),
      0,
      appendingLength
    );
  },

  finishedAppending(appendingLength) {
    this._changeArray(
      () => {
        this._appendingLength -= appendingLength;
      },
      this.get("posts.length") - appendingLength,
      appendingLength,
      appendingLength
    );
  },

  finishedPrepending(prependingLength) {
    this._changeArray(function() {}, 0, 0, prependingLength);
  },

  objectAt(index) {
    const posts = this.get("posts");
    return index < posts.length
      ? posts[index]
      : new Placeholder("post-placeholder");
  }
});
