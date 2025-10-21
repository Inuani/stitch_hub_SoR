const ffi = require("ffi-napi");
const ref = require("ref-napi");
const { spawn } = require("child_process");

var dllPath = "./libuFCoder-x86_64.so";

// Functions we need from the library
var uFCoder = ffi.Library(dllPath, {
  ReaderOpen: ["int", []],
  ReaderClose: ["int", []],
  GetDlogicCardType: ["byte", ["byte*"]],
  nt4h_set_global_parameters: ["int", ["byte", "byte", "byte"]],
  LinearRead: ["int", ["byte*", "ushort", "ushort", "ushort*", "byte", "byte"]],
  UFR_Status2String: ["string", ["int"]],
});

const T4T_AUTHENTICATION = {
  T4T_WITHOUT_PWD_AUTH: 0x60,
};

function openURL(url, browser = "firefox") {
  let command;
  let args;
  switch (process.platform) {
    case "darwin": // macOS
      if (browser === "chrome") {
        command = "open";
        args = ["-a", "Google Chrome", url];
      } else {
        command = "open";
        args = ["-a", "Firefox", url];
      }
      break;
    case "win32": // Windows
      if (browser === "chrome") {
        command = "cmd";
        args = ["/c", "start", "", "chrome", url];
      } else {
        command = "cmd";
        args = ["/c", "start", "", "firefox", url];
      }
      break;
    default: // Linux and others
      if (browser === "chrome") {
        command = "google-chrome";
        args = [url];
      } else {
        command = "firefox";
        args = [url];
      }
      break;
  }

  const spawnOptions = {
    detached: true,
    stdio: "ignore",
  };

  const launch = (cmd, cmdArgs, allowFallback = true) => {
    try {
      const child = spawn(cmd, cmdArgs, spawnOptions);
      child.on("error", (error) => {
        console.error("Error opening browser:", error);
        if (
          allowFallback &&
          process.platform !== "win32" &&
          process.platform !== "darwin"
        ) {
          launch("xdg-open", [url], false);
        }
      });
      child.unref();
    } catch (error) {
      console.error("Error opening browser:", error);
      if (
        allowFallback &&
        process.platform !== "win32" &&
        process.platform !== "darwin"
      ) {
        launch("xdg-open", [url], false);
      }
    }
  };

  launch(command, args);
}

// Main function to read SDM data and open browser
async function readSDMDataAndOpenBrowser(browser = "firefox") {
  // Open reader
  let status = uFCoder.ReaderOpen();
  if (status !== 0) {
    console.log("Failed to open reader:", uFCoder.UFR_Status2String(status));
    return;
  }
  console.log("Reader opened successfully");

  try {
    // Set global parameters for NDEF file
    const file_no = 2; // NDEF file number
    const key_no = 0x0e; // NDEF read key
    const comm_mode = 0; // Plain communication mode

    status = uFCoder.nt4h_set_global_parameters(file_no, key_no, comm_mode);
    if (status !== 0) {
      console.log(
        "Failed to set parameters:",
        uFCoder.UFR_Status2String(status),
      );
      return;
    }

    // Read NDEF data
    const read_data = Buffer.alloc(200); // Buffer for data
    const bytes_ret = ref.alloc("int", 0);

    status = uFCoder.LinearRead(
      read_data,
      0, // linear address
      200, // length to read
      bytes_ret,
      T4T_AUTHENTICATION.T4T_WITHOUT_PWD_AUTH,
      0, // reader key index
    );

    if (status !== 0) {
      console.log("Failed to read data:", uFCoder.UFR_Status2String(status));
      return;
    }

    // Parse NDEF message
    const ndef_length = read_data[4];
    const ndef_data = read_data.slice(7, 7 + ndef_length - 1);
    const url = ndef_data.toString("utf-8");

    console.log("Opening URL:", url);
    console.log("Using browser:", browser);

    openURL(url, browser);
  } finally {
    uFCoder.ReaderClose();
    console.log("Reader closed");
  }
}

// Get browser from command line argument (default: firefox)
const browser = process.argv[2] || "firefox";
readSDMDataAndOpenBrowser(browser).catch(console.error);
