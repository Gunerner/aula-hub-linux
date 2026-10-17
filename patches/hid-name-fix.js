/* aula-hub-linux: the Linux kernel names HID devices "<Manufacturer> <Product>"
   (e.g. "BY Tech Gaming Keyboard"); Windows reports only "<Product>". AULA Hub
   matches exact Windows product names, so strip the manufacturer prefix. */
(() => {
  try {
    const desc = Object.getOwnPropertyDescriptor(HIDDevice.prototype, "productName");
    const prefixes = ["BY Tech ", "Compx "];
    Object.defineProperty(HIDDevice.prototype, "productName", {
      configurable: true,
      enumerable: true,
      get() {
        const name = desc.get.call(this);
        for (const p of prefixes) if (name && name.startsWith(p)) return name.slice(p.length);
        return name;
      },
    });
  } catch (e) {
    console.warn("[aula-hub-linux] hid-name-fix failed", e);
  }
})();
