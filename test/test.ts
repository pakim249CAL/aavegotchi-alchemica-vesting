import * as fs from "fs";
import * as hre from "hardhat";
import { ethers } from "hardhat";
import { 
  Signer, 
  Contract, 
  ContractFactory,
  BigNumber } from "ethers";
import { expect } from "chai";
import {
  expectEvent,
  expectRevert,
} from "@openzeppelin/test-helpers";
import {
  deployVestingContract,
  increaseTime,
  mine,
  currentTimestamp,
} from "../helpers/helpers";
import {
  GWEI,
  ETHER,
} from "../helpers/constants";

describe("Vesting", function () {

  let signers: Signer[];
  let owner: Signer;
  let beneficiary: Signer;
  let token: Contract;
  let vestingContract: Contract;
  let startTime: BigNumber;

  before(async function () {
    signers = await ethers.getSigners();
    owner = signers[0];
    beneficiary = signers[1];
    let tokenFactory = await ethers.getContractFactory("Token");
    token = await tokenFactory.deploy();
    await token.deployed();
    startTime = BigNumber.from(await currentTimestamp());
  });

  describe("Nonrevocable Vesting Contract", function () {
    it("Should deploy an unrevocable vesting contract and deposit some tokens", async () => {
      vestingContract = await deployVestingContract(
        owner,
        beneficiary,
        startTime,
        BigNumber.from(10000),
        BigNumber.from(100000),
        false,
      );
      expect(await vestingContract.beneficiary()).to.equal(await beneficiary.getAddress());
      expect(await vestingContract.start()).to.equal(startTime);
      expect(await vestingContract.cliff()).to.equal(BigNumber.from(10000).add(startTime));
      expect(await vestingContract.duration()).to.equal(BigNumber.from(100000));
      expect(await vestingContract.revocable()).to.equal(false);
      expect(await vestingContract.released(token.address)).to.equal(BigNumber.from(0));
  
      await token.connect(owner).mint(vestingContract.address, ETHER);
      expect(await token.balanceOf(vestingContract.address)).to.equal(ETHER);
      expect(await vestingContract.releasableAmount(token.address)).to.equal(BigNumber.from(0));
    });
  
    it("Time passes but not past cliff. No tokens should be released.", async() => {
      await increaseTime(5000);
      await expectRevert(vestingContract.release(token.address), "TokenVesting: no tokens are due");
    });
  
    it("Time passes after cliff. Ensure right amount of tokens are released.", async() => {
  
    });
  
    it("Deposit more tokens. More tokens should release.", async() => {
  
    });
    
    it("Go past the duration. Do a partial release.", async() => {
  
    });
  
    it("Full release.", async() => {
  
    });
  });

  describe("Revocable Vesting Contract", function () {
    it("Should deploy a revocable vesting contract and deposit some tokens", async () => {
      // Reset the beneficiary's token balance
      await token.connect(owner).burn(
        await beneficiary.getAddress(), 
        await token.balanceOf(await beneficiary.getAddress()));
      expect(await token.balanceOf(await beneficiary.getAddress())).to.equal(BigNumber.from(0));

      startTime = BigNumber.from(await currentTimestamp());
      vestingContract = await deployVestingContract(
        owner,
        beneficiary,
        startTime,
        BigNumber.from(10000),
        BigNumber.from(100000),
        true,
      );
      expect(await vestingContract.beneficiary()).to.equal(await beneficiary.getAddress());
      expect(await vestingContract.start()).to.equal(startTime);
      expect(await vestingContract.cliff()).to.equal(BigNumber.from(10000).add(startTime));
      expect(await vestingContract.duration()).to.equal(BigNumber.from(100000));
      expect(await vestingContract.revocable()).to.equal(true);
      expect(await vestingContract.released(token.address)).to.equal(BigNumber.from(0));
  
      await token.connect(owner).mint(vestingContract.address, ETHER);
      expect(await token.balanceOf(vestingContract.address)).to.equal(ETHER);
      expect(await vestingContract.releasableAmount(token.address)).to.equal(BigNumber.from(0));
    });

    it("Time passes after cliff. Owner revokes. Beneficiary gets released tokens.", async() => {
      await increaseTime(19998);

      await vestingContract.connect(owner).revoke(token.address);
      expect(await token.balanceOf(vestingContract.address)).to.equal(ETHER.div(5));
      expect(await vestingContract.releasableAmount(token.address)).to.equal(ETHER.div(5));
      
      await vestingContract.release(token.address);
      expect(await token.balanceOf(vestingContract.address)).to.equal(BigNumber.from(0));
      expect(await token.balanceOf(await beneficiary.getAddress())).to.equal(ETHER.div(5));

    });


  });

});
