// Keep the native form value in sync while presenting an accessible, styled listbox.
export default {
  mounted() {
    this.trigger = this.el.querySelector('[role="combobox"]');
    this.menu = this.el.querySelector('[role="listbox"]');
    this.options = [...this.menu.querySelectorAll('[role="option"]')];
    this.open = false;
    this.search = "";

    this.listeners = new AbortController();
    const { signal } = this.listeners;

    this.el.addEventListener("click", (event) => {
      const option = event.target.closest('[role="option"]');
      if (option && this.menu.contains(option)) {
        this.choose(this.options.indexOf(option));
      } else if (this.trigger.contains(event.target)) {
        this.open ? this.close() : this.show();
      }
    }, { signal });

    this.menu.addEventListener("pointerdown", (event) => event.preventDefault(), { signal });
    this.menu.addEventListener("pointermove", (event) => {
      const option = event.target.closest('[role="option"]');
      if (option) this.activate(this.options.indexOf(option));
    }, { signal });

    this.trigger.addEventListener("keydown", (event) => this.keydown(event), { signal });
    document.addEventListener("pointerdown", (event) => {
      if (!this.el.contains(event.target)) this.close();
    }, { signal });

    const reposition = () => {
      if (this.open) this.position();
    };
    window.addEventListener("resize", reposition, { signal });
    window.addEventListener("scroll", reposition, { signal, capture: true });
    this.updated();
  },

  updated() {
    this.close();
    this.sync(this.el.dataset.value);
    this.trigger.disabled = this.el.dataset.disabled === "true";
    const invalid = this.el.dataset.invalid === "true";
    this.trigger.setAttribute("aria-invalid", String(invalid));
    if (invalid) {
      this.trigger.setAttribute("aria-describedby", `${this.el.dataset.inputId}-errors`);
    } else {
      this.trigger.removeAttribute("aria-describedby");
    }
  },

  sync(value) {
    this.value = value;
    this.options.forEach((option) => {
      option.setAttribute("aria-selected", String(option.dataset.value === value));
    });
    const selected = this.options.find((option) => option.dataset.value === value);
    this.trigger.querySelector("[data-select-label]").textContent = selected
      ? selected.querySelector("[data-option-label]").textContent
      : "Select";
  },

  show(index) {
    if (this.trigger.disabled) return;
    this.open = true;
    this.menu.hidden = false;
    this.trigger.setAttribute("aria-expanded", "true");
    this.position();
    const selected = this.options.findIndex((option) => option.dataset.value === this.value);
    this.activate(index ?? selected);
  },

  close() {
    this.open = false;
    this.menu.hidden = true;
    this.trigger.setAttribute("aria-expanded", "false");
    this.trigger.removeAttribute("aria-activedescendant");
    clearTimeout(this.searchTimeout);
    this.search = "";
  },

  activate(index) {
    this.active = Math.max(0, Math.min(index, this.options.length - 1));
    this.options.forEach((option, position) => {
      option.dataset.active = String(position === this.active);
    });
    const option = this.options[this.active];
    this.trigger.setAttribute("aria-activedescendant", option.id);
    option.scrollIntoView({ block: "nearest" });
  },

  choose(index) {
    const option = this.options[index];
    if (!option || this.trigger.disabled) return;
    const value = option.dataset.value;
    const input = document.getElementById(this.el.dataset.inputId);
    const changed = input.value !== value;
    input.value = value;
    this.sync(value);
    this.close();
    this.trigger.focus({ preventScroll: true });
    if (changed) input.dispatchEvent(new Event("change", { bubbles: true }));
  },

  keydown(event) {
    if (event.key === "Tab") {
      this.close();
      return;
    }
    if (event.key === "Escape") {
      if (this.open) {
        event.preventDefault();
        event.stopPropagation();
        this.close();
      }
      return;
    }
    if (["ArrowDown", "ArrowUp", "Home", "End", "Enter", " "].includes(event.key)) {
      event.preventDefault();
      if (event.key === "Enter" || event.key === " ") {
        this.open ? this.choose(this.active) : this.show();
      } else if (event.key === "Home" || event.key === "End") {
        this.show(event.key === "Home" ? 0 : this.options.length - 1);
      } else if (this.open) {
        this.activate(this.active + (event.key === "ArrowDown" ? 1 : -1));
      } else {
        this.show();
      }
    } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      event.preventDefault();
      if (!this.open) this.show();
      clearTimeout(this.searchTimeout);
      this.search += event.key.toLowerCase();
      const index = this.options.findIndex((option) =>
        option.querySelector("[data-option-label]").textContent.trim().toLowerCase().startsWith(this.search),
      );
      if (index >= 0) this.activate(index);
      this.searchTimeout = setTimeout(() => { this.search = ""; }, 600);
    }
  },

  position() {
    const rect = this.trigger.getBoundingClientRect();
    const width = Math.min(rect.width, window.innerWidth - 16);
    const below = window.innerHeight - rect.bottom - 12;
    const above = rect.top - 12;
    const upward = below < this.menu.scrollHeight && above > below;
    const height = Math.min(this.menu.scrollHeight, Math.max(40, upward ? above : below));
    Object.assign(this.menu.style, {
      width: `${width}px`,
      maxHeight: `${height}px`,
      left: `${Math.max(8, Math.min(rect.left, window.innerWidth - width - 8))}px`,
      top: `${upward ? rect.top - height - 6 : rect.bottom + 6}px`,
    });
  },

  destroyed() {
    clearTimeout(this.searchTimeout);
    this.listeners.abort();
  },
};
