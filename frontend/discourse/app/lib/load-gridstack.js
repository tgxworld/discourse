import { waitForPromise } from "@ember/test-waiters";

export default async function loadGridstack() {
  const promise = import("discourse/static/gridstack-bundle");
  waitForPromise(promise);
  return await promise;
}
