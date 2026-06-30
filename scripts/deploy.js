import hre from "hardhat";

async function main {
	const FastCoin = hre.ethers.getContractFactory('FastCoin');
	const fastCoin = await FastCoin.deploy(10);

	console.log("Deployment transaction hash:", 

	fastCoin.deploymentTransaction?.hash);
	console.log("Pending contract object:", fastCoin);
}
