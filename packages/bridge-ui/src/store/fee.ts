import { derived, writable } from "svelte/store";
import { ethers } from 'ethers';

import { ProcessingFeeMethod } from "../domain/fee";

export const processingFee = writable<ProcessingFeeMethod>(ProcessingFeeMethod.RECOMMENDED);
