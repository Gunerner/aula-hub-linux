/* aula-hub-linux: firmware updates are disabled. apply.py replaces every
   firmware call it knows of with a call to this function, which tells the user
   and throws, so no firmware data ever reaches the device code. */
(() => {
  const message =
    "Firmware updates are disabled in AULA Hub for Linux (aula-hub-linux).\n\n" +
    "Use AULA's official Windows software if you need to update firmware.";
  const block = () => {
    try {
      alert(message);
    } catch (e) {
      /* no dialog available; the error below still stops the update */
    }
    throw new Error("[aula-hub-linux] firmware update blocked");
  };
  Object.defineProperty(window, "__aulaHubLinuxBlockFirmware", {
    value: block,
    writable: false,
    configurable: false,
  });
})();
