import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import escape from "discourse/lib/escape";

module("Unit | Lib | ci-file-selection-proof", function (hooks) {
  setupTest(hooks);

  test("escapes markup in a newly added test file", function (assert) {
    assert.strictEqual(
      escape("<selection>&"),
      "&lt;selection&gt;&amp;",
      "the new test file executes the existing escaping utility"
    );
  });
});
