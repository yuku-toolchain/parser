var iter, result;
var thrownErr = new Error("Catch me.");
var caughtErr;
var order = 0;
var promises = [];
async function* g() {
  iter.throw(thrownErr).then(function () {}, function (e) {
    caughtErr = e;
    order++;
  });
  yield 1;
  yield 2;
}
iter = g();
iter.next().then(function (result) {
  iter.next().then(function (result) {}).then($DONE, $DONE);
}).catch($DONE);
