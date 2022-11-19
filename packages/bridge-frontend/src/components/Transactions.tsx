import React from "react";

const Transactions: React.FC<{}> = () => {
  const [transactions] = React.useState<Array<any>>([]);

  const headingElement = <h3 className="text-3xl">Transactions</h3>;

  if (transactions.length === 0) {
    return (
      <div className="flex flex-col w-full text-white p-4 max-w-[1280px] mx-auto mt-20">
        {headingElement}
        <div className="w-full italic text-white/80 h-40 flex items-center justify-center text-xl border border-slate-800 my-4">
          No transactions found
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col w-full text-white p-4 max-w-[1280px] mx-auto mt-20">
      {headingElement}
      <table className="text-white border border-slate-800 my-4">
        <thead>
          <tr>
            <th className="p-4">Date</th>
            <th>Amount</th>
            <th>From</th>
            <th>To</th>
            <th>Status</th>
            <th className="invisible">Action</th>
          </tr>
        </thead>
        <tbody>
          <tr className="text-center">
            <td className="py-2">18 Oct 2022</td>
            <td>0.1 ETH</td>
            <td>Mainnet</td>
            <td>Taiko</td>
            <td>Processing</td>
            <td className="flex justify-center">
              <button className="border border-taiko-pink px-4 py-1 text-sm flex items-center justify-center">
                Check Tx
              </button>
            </td>
          </tr>
          <tr className="text-center">
            <td className="py-2">18 Oct 2022</td>
            <td>0.1 ETH</td>
            <td>Mainnet</td>
            <td>Taiko</td>
            <td>Processed</td>
            <td className="flex justify-center">
              <button className="text-white font-bold bg-taiko-pink px-7 py-1 text-sm flex items-center justify-center">
                Claim
              </button>
            </td>
          </tr>
          <tr className="text-center">
            <td className="py-2">18 Oct 2022</td>
            <td>0.1 ETH</td>
            <td>Taiko</td>
            <td>Mainnet</td>
            <td>Processed</td>
            <td className="flex justify-center">
              <button
                disabled
                className="text-white font-bold bg-taiko-pink disabled:bg-taiko-pink/50 disabled:text-white/50 px-5 py-1 text-sm flex items-center justify-center"
              >
                Claimed
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
};

export default Transactions;
