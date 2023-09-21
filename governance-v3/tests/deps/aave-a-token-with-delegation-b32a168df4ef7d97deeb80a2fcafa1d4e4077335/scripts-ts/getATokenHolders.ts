import {ZeroAddress, ethers, JsonRpcProvider, Log, Interface, id, zeroPadBytes} from 'ethers';
import {getLogs} from './eventLogs';
import fs from 'fs';

import dotenv from 'dotenv';
dotenv.config();

export const roleGrantedEventABI = [
  'event Transfer(address indexed from, address indexed to, uint256 value)',
];

export const parseLog = (abi: string[], eventLog: any): {from: string; to: string} => {
  const iface = new Interface(abi);
  const parsedEvent = iface.parseLog(eventLog);
  // @ts-ignore
  const {from, to} = parsedEvent.args;

  return {from, to};
};

const getHolders = async () => {
  const aaveAToken = '0xA700b4eB416Be35b2911fd5Dee80678ff64fF6C9';

  const topic0 = id('Transfer(address,address,uint256)');

  const provider = new JsonRpcProvider(process.env.RPC_MAINNET);
  const topic1 = zeroPadBytes(ZeroAddress, 32);
  console.log(topic1);
  const logs = await getLogs({
    provider,
    address: aaveAToken,
    fromBlock: 1000000,
    maxBlock: 16931880,
    logs: [],
    topic0,
    topic1,
  });

  console.log('length: ', logs.eventLogs.length);

  const holders = new Set<string>();
  logs.eventLogs.forEach((eventLog) => {
    const {to} = parseLog(roleGrantedEventABI, eventLog);
    holders.add(to);
  });

  const object = {
    holders: [...holders].slice(0, 100),
  };

  fs.writeFileSync('./tests/utils/aTokenHolders.json', JSON.stringify(object));
};

getHolders().then().catch();
