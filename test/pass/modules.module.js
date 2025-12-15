import source foo from "module";
import source bar from './local-module.js';
import source baz from "../relative/path.js";

import source myModule from "some-module";
import source $dollarSign from "module";
import source _underscore from "module";
import source mixedCase123 from "module";

import defer * as foo from "module";
import defer * as bar from './local-module.js';
import defer * as baz from "../relative/path.js";

import defer * as myModule from "some-module";
import defer * as $dollarSign from "module";
import defer * as _underscore from "module";
import defer * as mixedCase123 from "module";

import "side-effect-module";
import './side-effect.js';
import "../another-side-effect.js";

import defaultExport from "module";
import React from 'react';
import Vue from 'vue';

import * as ns from "module";
import * as Utils from './utils.js';
import * as Helpers from '../helpers.js';

import { named } from "module";
import { foo } from './module.js';

import { foo, bar } from "module";
import { a, b, c } from './module.js';
import { one, two, three, four } from "multi-export";

import { foo as bar } from "module";
import { originalName as newName } from './module.js';
import { a as x, b as y, c as z } from "module";

import { foo, bar as baz, qux } from "module";
import { default as def, named } from './module.js';

import defaultExport, * as ns from "module";
import React, * as ReactAll from 'react';
import Vue, * as VueAll from 'vue';

import defaultExport, { named } from "module";
import React, { Component } from 'react';
import Vue, { computed, ref } from 'vue';
import defaultExport, { foo, bar, baz } from "module";
import myDefault, { a as x, b as y } from './module.js';

import "module" with { type: "json" };
import './data.json' with { type: "json" };

import data from "module" with { type: "json" };
import config from './config.json' with { type: "json" };

import * as data from "module" with { type: "json" };
import * as styles from './styles.css' with { type: "css" };

import { foo } from "module" with { type: "json" };
import { a, b, c } from './data.json' with { type: "json" };
import { foo as bar } from "module" with { type: "wasm" };

import defaultExport, * as ns from "module" with { type: "json" };
import defaultExport, { named } from "module" with { type: "json" };
import React, { Component, useState } from 'react' with { type: "module" };

import data from "module" with { type: "json", integrity: "sha384-xyz" };
import "module" with { type: "json", format: "module", custom: "value" };

import data from "module" with { "type": "json" };
import "module" with { "custom-key": "value", "another-key": "value2" };
import foo from './module.js' with { "content-type": "application/json" };

import data from "module" with { type: "json", "custom-key": "value" };
import "module" with { "hyphen-key": "value", normalKey: "value2" };

import data from "module" with { type: "json", };
import "module" with { type: "json", format: "module", };
import { foo } from "module" with { type: "wasm", };

import "module" assert { type: "json" };
import './data.json' assert { type: "json" };

import data from "module" assert { type: "json" };
import config from './config.json' assert { type: "json" };

import * as data from "module" assert { type: "json" };
import * as styles from './styles.css' assert { type: "css" };

import { foo } from "module" assert { type: "json" };
import { a, b, c } from './data.json' assert { type: "json" };

import defaultExport, * as ns from "module" assert { type: "json" };
import defaultExport, { named } from "module" assert { type: "json" };

import data from "module" assert { type: "json", integrity: "sha384-xyz" };

import data from "module" assert { "type": "json", "custom-key": "value" };

import data from "module" assert { type: "json", };

export { foo as "string-export" } from './module.js';
export { "input-name" as "output-name" } from './module.js';

export * from "module" with { type: "json" };
export * as ns from "module" with { type: "json" };
export * from './module.js' assert { type: "css" };

export { foo } from "module" with { type: "json" };

export { "string-name" as localName } from './module.js' with { type: "json" };

import { foo, } from "module";
import { bar, } from './module.js';

import { a, b, c, } from "module";
import { foo, bar, baz, } from './module.js';

import { foo as bar, } from "module";
import { a as x, b as y, } from './module.js';

import defaultExport, { foo, bar, } from "module";

import { foo, bar, } from "module" with { type: "json" };
import { a, b, c, } from './module.js' with { type: "json", };

import { } from "module";
import { } from './module.js' with { type: "json" };

import defaultExport, { named1, named2 as alias2 } from "@scope/package/subpath";
import * as ns from "@org/pkg/deep/nested/path.js" with { type: "module" };
import def, * as all from "../../../deeply/nested/relative/path.js";

import { as as asAlias } from "module";
import { if as ifAlias } from "module";
import { default as defaultValue } from "module";

import { get, set } from "module";
import { static as staticValue } from "module";

import data from "module" with {
  type: "json",
  integrity: "sha384-abc123",
  "custom-attribute": "custom-value",
  nonce: "random-nonce",
};

import {
  foo,
  bar,
  baz,
} from "module" with {
  type: "json",
  format: "module",
};

import pkg from "package-name";
import scoped from "@scope/package";
import nested from "@scope/package/nested";

import local from "./local";
import parent from "../parent";
import ancestor from "../../ancestor";

import js from "./file.js";
import mjs from "./file.mjs";
import json from "./data.json" with { type: "json" };
import css from "./styles.css" with { type: "css" };
import wasm from "./module.wasm" with { type: "wasm" };

import noExt from "./module";

import index from "./";
import indexExplicit from "./index";

import deep from "./a/b/c/d/e/f/module.js";
import deepRelative from "../../../x/y/z/module.js";

import _private from "module";
import { _internal } from "module";
import * as _utils from "module";

import $jquery from "module";
import { $scope } from "module";
import * as $lib from "module";

import module1 from "module";
import { func2, class3 } from "module";
import * as utils4 from "module";

import myModule123 from "module";
import { myFunc456, MyClass789 } from "module";

import veryLongIdentifierNameThatIsStillValid from "module";
import { anotherVeryLongIdentifierWithManyCharacters } from "module";

import{foo}from"module";
import{a,b,c}from"module"with{type:"json"};

import     defaultExport     from     "module"     ;
import   {   foo   ,   bar   }   from   "module"   ;

import {
  multiline1,
  multiline2,
  multiline3
} from "module";

import {
  a as x,
  b as y,
  c as z,
} from "module" with {
  type: "json",
  format: "module",
};

import defaultMultiline, {
  named1,
  named2,
  named3,
} from "module";

import multilineDefault, * as multilineNs from "module" with {
  type: "json",
};

import { as as asKeyword } from "module";

import { from as fromKeyword } from "module";

import { with as withKeyword } from "module";

import { assert as assertKeyword } from "module";

import { type } from "module";
import { type as typeAlias } from "module";

import source onlyDefault from "module";

import defer * as onlyNamespace from "module";

import "side-effect" with { type: "json" };
import def from "mod" with { type: "json" };
import * as ns from "mod" with { type: "json" };
import { n } from "mod" with { type: "json" };
import d, * as n from "mod" with { type: "json" };
import d, { n } from "mod" with { type: "json" };

import "side-effect" assert { type: "json" };
import def from "mod" assert { type: "json" };
import * as ns from "mod" assert { type: "json" };
import { n } from "mod" assert { type: "json" };
import d, * as n from "mod" assert { type: "json" };
import d, { n } from "mod" assert { type: "json" };

import React, { useState, useEffect, useCallback } from 'react';
import Vue, { ref, computed, watch, onMounted } from 'vue';
import * as THREE from 'three' with { type: "module" };
import defaultExport, { namedExport, another as renamed } from '@company/package/submodule';

import config from './config.json' with {
  type: "json",
  integrity: "sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC",
};
