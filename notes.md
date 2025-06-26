### notes

- There are 7 less tests here than the hardhat project, because the `Updraft_Test.t.sol` is handling what were duplicate (deployment tests) in the hardhat version
- [hardhat test for position-self-transfer#198](https://github.com/UpdraftFund/updraft-contracts/blob/f74f20c09ad9fcda56c1a03380bff050999bd79b/test/position-self-transfer.test.ts#L198) is expecting the `initialStartCycleIndex` to be the second field of the `Solution::Position Struct`, but that is actually the `uint256 contributionTime`; thusly, line 199 of the original hardhat test is also wrong


#### todo

- Refactor
- Code reviews
- handle anvil/sepolia/etc deployments testing
- fuzz test values (start with constructors)
- bring back GitHub CI
