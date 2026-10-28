import React from 'react';

const QrTile: React.FC<{ qrCode: string }> = ({ qrCode }) => (
  <div className="flex h-[184px] w-[184px] items-center justify-center rounded-xl border border-slate-200 bg-white p-3">
    <img src={qrCode} alt="QR code to add Zyndio to your authenticator app" className="h-full w-full" />
  </div>
);

export default QrTile;
