const TimeLock = artifacts.require('TimeLock')
const Test = artifacts.require('TestTimeLock')

const BN = web3.utils.BN;
require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BN)).should()

const {	latest,	increaseTo, duration } = require('./helpers/time');

const TIME_TO_WAIT = 1000

contract('TimeLock', (accounts) => {

	describe('TimeLock', () => {
		it('should only let queued transaction through', async () => {
			// Initialize contracts
			const timelock = await TimeLock.new()
			const test = await Test.new(timelock.address)

			// Get variable to change
			const sum1 = Number(await test.sum())
			
			// Get timestamp to execute
			const timestamp = Number(await timelock.getTimestamp(TIME_TO_WAIT))

			// Reject before queued
			await timelock.execute(test.address, 0, "test()", 0x00, timestamp).should.be.rejectedWith('revert')

			// Queue function
			await timelock.queue(test.address, 0, "test()", 0x00, timestamp)

			// Reject before timestamp
			await timelock.execute(test.address, 0, "test()", 0x00, timestamp).should.be.rejectedWith('revert')

			// Wait until timestamp
			let start = await latest()
			let end = start.add(duration.minutes(TIME_TO_WAIT + 1))
			await increaseTo(end)

			// Execute
			await timelock.execute(test.address, 0, "test()", 0x00, timestamp)

			// Reject after executing
			await timelock.execute(test.address, 0, "test()", 0x00, timestamp).should.be.rejectedWith('revert')

			// Check if sum is increased
			const sum2 = Number(await test.sum())
			assert.equal(sum1 + 1, sum2)
		})
	})
})