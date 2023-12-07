// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; // 100000000000000000
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // console.log(fundMe.i_owner());
        // console.log(msg.sender);
        // console.log(address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        console.log(version);
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // hey, the next line should revert
        //assert(This tx fails/reverts)
        fundMe.fund(); //send 0 value which is less than 5 dollars
        //this transaction fails/reverts because we don't send enough ETH
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // the next TX will be sent by USER
        fundMe.fund{value: SEND_VALUE}(); // send 10 ETH which is more than the minimum requirement of $5

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArraysOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        // first fund the contract
        // the following two lines are skipped because of the use of modifier funded
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        // then let the USER try to withdraw; the USER is not the OWNER; Expected to revert.
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        // --- we have to compare the balance before and after the withdrawal process
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance; //we fund the contract with SEND_VALUE

        // Act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw(); // should have spent gas?

        uint256 gasLeft = gasleft(); // calculate the remaining gas so we can compare with the initial one
        uint256 gasUsed = (gasStart - gasLeft) * tx.gasprice;
        console.log(gasUsed);

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        // ARRANGE

        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // make sure you don't use address 0, because sometimes it reverts, make sanity checks you don't use 0 address
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank new address
            // vm.deal new address
            // address()
            hoax(address(i), SEND_VALUE); // setting an address with some amount of eth = SEND_VALUE
            // fund the FundMe
            fundMe.fund{value: SEND_VALUE}(); // funding the fundMe with SEND_VALUE eth
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance; //we fund the contract with SEND_VALUE

        // ACT
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // ASSERT
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // ARRANGE

        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // make sure you don't use address 0, because sometimes it reverts, make sanity checks you don't use 0 address
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank new address
            // vm.deal new address
            // address()
            hoax(address(i), SEND_VALUE); // setting an address with some amount of eth = SEND_VALUE
            // fund the FundMe
            fundMe.fund{value: SEND_VALUE}(); // funding the fundMe with SEND_VALUE eth
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance; //we fund the contract with SEND_VALUE

        // ACT
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();

        // ASSERT
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }
}
