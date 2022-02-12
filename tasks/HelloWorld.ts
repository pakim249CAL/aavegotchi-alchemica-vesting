import { task } from "hardhat/config";

task("Hello World", "Hello World").setAction(async (_, hre) => {
  
});

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
