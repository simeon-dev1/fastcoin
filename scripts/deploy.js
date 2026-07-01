import hre from "hardhat";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const FastCoin = await hre.ethers.getContractFactory("Fastcoin");
  const fastCoin = await FastCoin.deploy(1000000);

  await fastCoin.waitForDeployment();
  
  const address = await fastCoin.getAddress();
  console.log("FastCoin deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
