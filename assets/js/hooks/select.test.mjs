import test from "node:test";
import assert from "node:assert/strict";
import Select from "./select.mjs";

// Small DOM doubles exercise the hook's events and LiveView synchronization without dependencies.
class Element extends EventTarget {
  constructor(id, dataset = {}) {
    super();
    this.id = id;
    this.dataset = dataset;
    this.attributes = {};
    this.style = {};
    this.children = [];
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  removeAttribute(name) { delete this.attributes[name]; }
  contains(node) { return node === this || this.children.some((child) => child.contains?.(node)); }
  querySelector(selector) { return this.queries[selector]; }
  querySelectorAll() { return this.children; }
  scrollIntoView() {}
  focus() { this.focused = true; }
  getBoundingClientRect() { return { left: 20, top: 40, bottom: 80, width: 180 }; }
}

function fixture(t) {
  const input = new Element("planet");
  input.value = "earth";
  const trigger = new Element("planet-trigger");
  const label = { textContent: "Earth" };
  trigger.queries = { "[data-select-label]": label };
  const menu = new Element("planet-listbox");
  menu.scrollHeight = 130;
  menu.children = ["earth", "moon", "mars"].map((value) => {
    const option = new Element(`planet-${value}`, { value });
    option.queries = { "[data-option-label]": { textContent: value[0].toUpperCase() + value.slice(1) } };
    return option;
  });
  const el = new Element("planet-control", { inputId: "planet", value: "earth", disabled: "false", invalid: "false" });
  el.children = [trigger, menu];
  el.queries = { '[role="combobox"]': trigger, '[role="listbox"]': menu };
  const document = new EventTarget();
  document.getElementById = () => input;
  const window = new EventTarget();
  window.innerHeight = 600;
  window.innerWidth = 800;
  const oldDocument = globalThis.document;
  const oldWindow = globalThis.window;
  globalThis.document = document;
  globalThis.window = window;
  const hook = { ...Select, el };
  hook.mounted();
  t.after(() => {
    hook.destroyed();
    globalThis.document = oldDocument;
    globalThis.window = oldWindow;
  });
  const key = (value) => {
    const event = new Event("keydown", { cancelable: true });
    Object.defineProperty(event, "key", { value });
    trigger.dispatchEvent(event);
    return event;
  };
  return { hook, key, input, trigger, menu, label, el, document, window };
}

test("arrow keys navigate without committing; Enter updates the form once", (t) => {
  const { key, input, trigger, menu, label } = fixture(t);
  let changes = 0;
  input.addEventListener("change", () => changes++);
  key("ArrowDown");
  assert.equal(trigger.attributes["aria-expanded"], "true");
  key("ArrowDown");
  assert.equal(trigger.attributes["aria-activedescendant"], "planet-moon");
  assert.equal(input.value, "earth");
  key("Enter");
  assert.equal(input.value, "moon");
  assert.equal(label.textContent, "Moon");
  assert.equal(changes, 1);
  assert.equal(menu.hidden, true);
  assert.equal(trigger.focused, true);
  key("Enter");
  key("Enter");
  assert.equal(changes, 1);
});

test("Escape and Tab dismiss without modifying the selection", (t) => {
  const { key, input, menu, trigger } = fixture(t);
  key("End");
  key("Escape");
  assert.equal(input.value, "earth");
  assert.equal(menu.hidden, true);
  assert.equal(trigger.attributes["aria-activedescendant"], undefined);
  key("Home");
  assert.equal(key("Tab").defaultPrevented, false);
  assert.equal(menu.hidden, true);
});

test("typeahead finds Mars and Space commits it", (t) => {
  const { key, input, trigger } = fixture(t);
  key("m");
  key("a");
  assert.equal(trigger.attributes["aria-activedescendant"], "planet-mars");
  key(" ");
  assert.equal(input.value, "mars");
});

test("LiveView patches synchronize presets, validation, and disabled states", (t) => {
  const { hook, el, label, menu, trigger } = fixture(t);
  hook.show();
  el.dataset.value = "mars";
  el.dataset.invalid = "true";
  hook.updated();
  assert.equal(label.textContent, "Mars");
  assert.equal(menu.hidden, true);
  assert.equal(menu.children[2].attributes["aria-selected"], "true");
  assert.equal(trigger.attributes["aria-describedby"], "planet-errors");
  el.dataset.invalid = "false";
  el.dataset.disabled = "true";
  hook.updated();
  hook.show();
  assert.equal(menu.hidden, true);
  assert.equal(trigger.attributes["aria-describedby"], undefined);
});

test("outside pointer presses dismiss and destroy removes document listeners", (t) => {
  const { hook, document, menu } = fixture(t);
  hook.show();
  document.dispatchEvent(new Event("pointerdown"));
  assert.equal(menu.hidden, true);
  hook.show();
  hook.destroyed();
  document.dispatchEvent(new Event("pointerdown"));
  assert.equal(menu.hidden, false);
});

test("menus open above the trigger when the viewport has no space below", (t) => {
  const { hook, trigger, menu, window } = fixture(t);
  window.innerHeight = 500;
  trigger.getBoundingClientRect = () => ({ left: 700, top: 440, bottom: 480, width: 180 });
  hook.show();
  assert.equal(menu.style.top, "304px");
  assert.equal(menu.style.left, "612px");
});
