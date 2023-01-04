import { expect } from "chai";
// import * as log from "../tasks/log"

const hre = require("hardhat");
const ethers = hre.ethers;

describe("Lib1559Math", function () {
    let Lib1559Math: any;
    before(async function () {
        Lib1559Math = await (
            await ethers.getContractFactory("TestLib1559Math")
        ).deploy();
    });

    describe("Testing adjustTarget", function () {
        it("testing adjustTarget works as docs intend", async function () {
            // 15000000 * ((9) * 15000000 + 10000000) == 2.175E15
            //  divide by:
            // (10 * 15000000) == 1.5E8
            // == 1.45E7
            const initTarget = 15000000;
            const prevMeasurement = 10000000;
            const baseTarget = 15000000;
            const adjustFactor = 10;

            const result = await Lib1559Math.adjustTarget(
                initTarget,
                prevMeasurement,
                baseTarget,
                adjustFactor
            );
            expect(result).to.equal(14500000);
        });

        it("testing adjustTarget iterative is increasing", async function () {
            //  (since prevMeasured > T, nextTarget > prevTarget) as described in Lib1559Math.sol
            const initTarget = 10000000;
            const prevMeasured = 20000000;
            const baseTarget = 15000000;
            const adjustFactor = 10;

            let target = await Lib1559Math.adjustTarget(
                initTarget,
                prevMeasured,
                baseTarget,
                adjustFactor
            );
            const arr: any[] = [];
            for (let index = 0; index < 10; index++) {
                target = await Lib1559Math.adjustTarget(
                    target,
                    prevMeasured,
                    baseTarget,
                    adjustFactor
                );
                arr.push(target);
                // log.info(target)
            }
            // eslint-disable-next-line eqeqeq
            const isAscending = arr.every((x, i) => {
                return i === 0 || x >= arr[i - 1];
            });
            expect(isAscending).to.equal(true);
        });
    });

    describe("Testing adjustTargetReverse", function () {
        it("testing adjustTargetReverse works as docs intend", async function () {
            // (15000000 * 10 * 15000000) == 2.25E15
            // divide by:
            // ((9) * 15000000 + 10000000) == 1.45E8
            // == 15,517,241.379310345
            // == 15517241
            const initTarget = 15000000;
            const prevMeasurement = 10000000;
            const baseTarget = 15000000;
            const adjustFactor = 10;

            const result = await Lib1559Math.adjustTargetReverse(
                initTarget,
                prevMeasurement,
                baseTarget,
                adjustFactor
            );
            expect(result).to.equal(15517241);
        });

        it("testing adjustTargetReverse iterative is decreasing", async function () {
            // (since prevTarget >= T, nextTarget < prevTarget) as described in Lib1559Math.sol
            const initTarget = 15000000;
            const prevMeasurement = 20000000;
            const baseTarget = 15000000;
            const adjustFactor = 10;

            let target = await Lib1559Math.adjustTargetReverse(
                initTarget,
                prevMeasurement,
                baseTarget,
                adjustFactor
            );
            const arr: any[] = [];
            for (let index = 0; index < 10; index++) {
                target = await Lib1559Math.adjustTargetReverse(
                    target,
                    prevMeasurement,
                    baseTarget,
                    adjustFactor
                );
                arr.push(target);
                // log.info(target)
            }
            // eslint-disable-next-line eqeqeq
            const isDescending = arr.every((x, i) => {
                return i === 0 || x <= arr[i - 1];
            });
            expect(isDescending).to.equal(true);
        });
    });
});
