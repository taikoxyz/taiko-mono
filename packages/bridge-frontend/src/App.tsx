import React from "react";
import { Link, BrowserRouter as Router, Routes, Route } from "react-router-dom";

import Home from "./pages/Home";

function App() {
  const [wallet, setWallet] = React.useState();
  return (
    <Router>
      <header className="bg-white h-12 p-2 flex items-center justify-between text-taiko-blue">
        <Link to="/" className="flex items-center text-taiko-blue">
          <img src="/taikologo.png" alt="" height={48} width={48} />
          <span className="text-xl">Taiko</span>
        </Link>

        <button
          type="button"
          className={`${
            wallet
              ? "bg-transparent border border-taiko-pink"
              : "bg-taiko-pink text-white"
          } w-[150px] rounded-md py-2`}
        >
          {wallet ? "0x1234...678" : "Connect Wallet"}
        </button>
      </header>

      <main className="bg-taiko-blue h-[calc(100vh-48px)] text-taiko-blue">
        <Routes>
          <Route path="/" element={<Home />} />
        </Routes>
      </main>
    </Router>
  );
}

export default App;
