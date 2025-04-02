import { ethers } from "ethers";
import dotenv from "dotenv";
import fs from "fs";
var cron = require("node-cron");

dotenv.config();

// Load environment variables
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const RPC_URL = process.env.RPC_URL || "";
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || "";
const ABI = ["function rollover() public"];

const LOG_FILE = "rollover.log";

if (!PRIVATE_KEY || !RPC_URL || !CONTRACT_ADDRESS) {
  console.error(
    "Please provide PRIVATE_KEY, RPC_URL, and CONTRACT_ADDRESS in your .env file"
  );
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

async function logMessage(message: string) {
  const timestamp = new Date().toISOString();
  const log = `${timestamp} - ${message}\n`;
  fs.appendFileSync(LOG_FILE, log, "utf8");
}

async function callRollover() {
  try {
    console.log("Calling rollover()...");
    const tx = await contract.rollover();
    console.log("Transaction sent:", tx.hash);

    const receipt = await tx.wait();
    const successMessage = `Success called at ${new Date().toISOString()} with tx id: ${
      receipt.transactionHash
    }`;
    console.log(successMessage);
    await logMessage(successMessage);
  } catch (error) {
    const errorMessage = `Failed at ${new Date().toISOString()} - Error: ${error}`;
    console.error(errorMessage);
    await logMessage(errorMessage);
  }
}

async function init() {
  try {
    const blockNumber = await provider.getBlockNumber();
    console.log(
      `Connected to blockchain. Current block number: ${blockNumber}`
    );

    // Call rollover immediately before starting the cron job
    await callRollover();

    //  once per day at exactly 00:00:05 (UTC): 5 0 0 * * *
    cron.schedule("5 * * * * *", async () => {
      await callRollover();
    });

    console.log(
      "Cron job scheduled to run every minute starting at UTC 00:00:05."
    );
  } catch (error) {
    console.error("Failed to connect to the blockchain:", error);
    await logMessage(`Failed to connect to the blockchain - Error: ${error}`);
  }
}

// Initialize the application
init();
