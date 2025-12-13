function foo() {
  return;
}

function bar() {
  return 42;
}

function baz() {
  throw new Error("oops");
}

try {
  dangerous();
} catch (e) {
  console.log(e);
}

try {
  dangerous();
} catch {
  console.log("error");
}

try {
  dangerous();
} finally {
  cleanup();
}

try {
  dangerous();
} catch (e) {
  console.log(e);
} finally {
  cleanup();
}

debugger;
