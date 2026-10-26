import React, { useState, useEffect } from 'react';
import { Watch, Activity, Zap, Circle, CheckCircle2, RefreshCw, X, Settings, Battery } from 'lucide-react';
import { ConnectedDevice, DeviceType } from '../types';
import { AVAILABLE_DEVICES } from '../constants';
import { generateTodayMetrics, simulateSync } from '../utils/wearableData';

const Devices: React.FC = () => {
    const [connectedDevices, setConnectedDevices] = useState<ConnectedDevice[]>([
        {
            id: 'apple-watch-1',
            type: 'apple-watch',
            name: 'Apple Watch Series 9',
            connected: true,
            lastSync: new Date(Date.now() - 1000 * 60 * 15), // 15 min ago
            battery: 78
        }
    ]);

    const [pairingDevice, setPairingDevice] = useState<DeviceType | null>(null);
    const [isPairing, setIsPairing] = useState(false);
    const [syncingDevice, setSyncingDevice] = useState<string | null>(null);
    const [selectedDevice, setSelectedDevice] = useState<ConnectedDevice | null>(null);

    // Handle device pairing
    const handleConnect = async (deviceType: DeviceType) => {
        const device = AVAILABLE_DEVICES.find(d => d.type === deviceType);
        if (!device) return;

        setPairingDevice(deviceType);
        setIsPairing(true);

        // Simulate pairing process
        await new Promise(resolve => setTimeout(resolve, 2000));

        const newDevice: ConnectedDevice = {
            id: `${deviceType}-${Date.now()}`,
            type: deviceType,
            name: device.name,
            connected: true,
            lastSync: new Date(),
            battery: 85 + Math.floor(Math.random() * 15)
        };

        setConnectedDevices([...connectedDevices, newDevice]);
        setIsPairing(false);
        setPairingDevice(null);
    };

    // Handle device disconnection  
    const handleDisconnect = (deviceId: string) => {
        setConnectedDevices(connectedDevices.filter(d => d.id !== deviceId));
        if (selectedDevice?.id === deviceId) setSelectedDevice(null);
    };

    // Handle manual sync
    const handleSync = async (deviceId: string) => {
        setSyncingDevice(deviceId);
        await simulateSync(deviceId);

        setConnectedDevices(connectedDevices.map(d =>
            d.id === deviceId ? { ...d, lastSync: new Date() } : d
        ));
        setSyncingDevice(null);
    };

    const getColorClasses = (color: string) => {
        const colors: Record<string, any> = {
            blue: { bg: 'bg-blue-50', text: 'text-blue-600', border: 'border-blue-200', badge: 'bg-blue-100' },
            teal: { bg: 'bg-teal-50', text: 'text-teal-600', border: 'border-teal-200', badge: 'bg-teal-100' },
            amber: { bg: 'bg-amber-50', text: 'text-amber-600', border: 'border-amber-200', badge: 'bg-amber-100' },
            yellow: { bg: 'bg-yellow-50', text: 'text-yellow-600', border: 'border-yellow-200', badge: 'bg-yellow-100' }
        };
        return colors[color] || colors.blue;
    };

    const getDeviceIcon = (deviceType: DeviceType) => {
        switch (deviceType) {
            case 'apple-watch': return Watch;
            case 'fitbit': return Activity;
            case 'garmin': return Activity;
            case 'oura': return Circle;
            case 'whoop': return Zap;
            default: return Watch;
        }
    };

    const getTimeSinceSync = (lastSync: Date) => {
        const minutes = Math.floor((Date.now() - lastSync.getTime()) / 1000 / 60);
        if (minutes < 1) return 'Just now';
        if (minutes < 60) return `${minutes}m ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours}h ago`;
        return `${Math.floor(hours / 24)}d ago`;
    };

    return (
        <div className="space-y-6 md:space-y-8 pb-20 md:pb-0">

            {/* Header */}
            <div className="bg-gradient-to-r from-brand-dark to-slate-800 p-6 md:p-8 rounded-2xl md:rounded-3xl text-white relative overflow-hidden">
                <div className="relative z-10">
                    <h1 className="text-2xl md:text-3xl font-serif font-bold mb-2">Connected Devices</h1>
                    <p className="text-slate-300 text-sm md:text-base">
                        Connect your wearables to track health metrics and get personalized insights
                    </p>
                </div>
                <div className="absolute right-0 top-0 w-32 h-32 bg-white/10 rounded-full -mr-10 -mt-10 blur-2xl"></div>
            </div>

            {/* Connected Devices */}
            {connectedDevices.length > 0 && (
                <div>
                    <h2 className="text-lg font-bold text-stone-800 mb-4 flex items-center gap-2">
                        <span className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></span>
                        Connected ({connectedDevices.length})
                    </h2>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {connectedDevices.map(device => {
                            const deviceDef = AVAILABLE_DEVICES.find(d => d.type === device.type);
                            if (!deviceDef) return null;

                            const colors = getColorClasses(deviceDef.color);
                            const Icon = getDeviceIcon(device.type);
                            const isSyncing = syncingDevice === device.id;
                            const metrics = generateTodayMetrics(device.type);

                            return (
                                <div key={device.id} className="bg-white rounded-2xl p-5 border border-stone-100 shadow-sm">
                                    {/* Header */}
                                    <div className="flex items-start justify-between mb-4">
                                        <div className="flex items-center gap-3">
                                            <div className={`p-3 ${colors.bg} rounded-xl`}>
                                                <Icon className={`w-6 h-6 ${colors.text}`} />
                                            </div>
                                            <div>
                                                <h3 className="font-bold text-stone-800">{device.name}</h3>
                                                <p className="text-xs text-stone-500 flex items-center gap-1">
                                                    <span className="w-1.5 h-1.5 bg-emerald-500 rounded-full"></span>
                                                    Connected
                                                </p>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => setSelectedDevice(selectedDevice?.id === device.id ? null : device)}
                                            className="p-2 hover:bg-stone-100 rounded-lg transition-colors"
                                        >
                                            <Settings className="w-4 h-4 text-stone-400" />
                                        </button>
                                    </div>

                                    {/* Quick Stats */}
                                    <div className="grid grid-cols-2 gap-3 mb-4">
                                        <div className="bg-stone-50 rounded-lg p-3">
                                            <div className="text-xs text-stone-500 mb-1">Steps</div>
                                            <div className="text-lg font-bold text-stone-800">{metrics.steps.toLocaleString()}</div>
                                        </div>
                                        <div className="bg-stone-50 rounded-lg p-3">
                                            <div className="text-xs text-stone-500 mb-1">Heart Rate</div>
                                            <div className="text-lg font-bold text-stone-800">{metrics.heartRate.avg} bpm</div>
                                        </div>
                                    </div>

                                    {/* Sync Info */}
                                    <div className="flex items-center justify-between pt-3 border-t border-stone-100">
                                        <div className="flex items-center gap-2 text-xs text-stone-500">
                                            {device.battery && (
                                                <>
                                                    <Battery className="w-3 h-3" />
                                                    <span>{device.battery}%</span>
                                                    <span className="text-stone-300">•</span>
                                                </>
                                            )}
                                            <span>Synced {getTimeSinceSync(device.lastSync)}</span>
                                        </div>
                                        <button
                                            onClick={() => handleSync(device.id)}
                                            disabled={isSyncing}
                                            className={`p-2 hover:bg-stone-100 rounded-lg transition-colors ${isSyncing ? 'animate-spin' : ''}`}
                                        >
                                            <RefreshCw className="w-4 h-4 text-stone-600" />
                                        </button>
                                    </div>

                                    {/* Device Settings Panel */}
                                    {selectedDevice?.id === device.id && (
                                        <div className="mt-4 pt-4 border-t border-stone-100">
                                            <button
                                                onClick={() => handleDisconnect(device.id)}
                                                className="w-full py-2 text-sm text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                            >
                                                Disconnect Device
                                            </button>
                                        </div>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </div>
            )}

            {/* Available Devices */}
            <div>
                <h2 className="text-lg font-bold text-stone-800 mb-4">Available Devices</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {AVAILABLE_DEVICES.map(device => {
                        const isConnected = connectedDevices.some(d => d.type === device.type);
                        if (isConnected) return null;

                        const colors = getColorClasses(device.color);
                        const Icon = getDeviceIcon(device.type);
                        const isPairingThis = pairingDevice === device.type;

                        return (
                            <div key={device.id} className="bg-white rounded-2xl p-5 border border-stone-100 hover:border-stone-200 transition-all">
                                <div className="flex items-start gap-3 mb-4">
                                    <div className={`p-3 ${colors.bg} rounded-xl`}>
                                        <Icon className={`w-6 h-6 ${colors.text}`} />
                                    </div>
                                    <div className="flex-1">
                                        <h3 className="font-bold text-stone-800 mb-1">{device.name}</h3>
                                        <p className="text-xs text-stone-500">{device.description}</p>
                                    </div>
                                </div>

                                {/* Features */}
                                <div className="flex flex-wrap gap-1.5 mb-4">
                                    {device.features.slice(0, 4).map((feature, i) => (
                                        <span key={i} className={`px-2 py-1 ${colors.badge} ${colors.text} text-[10px] font-medium rounded-full`}>
                                            {feature}
                                        </span>
                                    ))}
                                    {device.features.length > 4 && (
                                        <span className="px-2 py-1 bg-stone-100 text-stone-600 text-[10px] font-medium rounded-full">
                                            +{device.features.length - 4}
                                        </span>
                                    )}
                                </div>

                                {/* Connect Button */}
                                <button
                                    onClick={() => handleConnect(device.type)}
                                    disabled={isPairingThis || isPairing}
                                    className="w-full py-2.5 bg-brand-dark text-white rounded-xl font-medium hover:bg-slate-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
                                >
                                    {isPairingThis ? (
                                        <>
                                            <RefreshCw className="w-4 h-4 animate-spin" />
                                            Pairing...
                                        </>
                                    ) : (
                                        'Connect Device'
                                    )}
                                </button>
                            </div>
                        );
                    })}
                </div>
            </div>

            {/* Empty State */}
            {connectedDevices.length === 0 && (
                <div className="bg-stone-50 border border-stone-200 border-dashed rounded-2xl p-12 text-center">
                    <div className="w-16 h-16 bg-stone-200 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Watch className="w-8 h-8 text-stone-400" />
                    </div>
                    <h3 className="text-lg font-bold text-stone-700 mb-2">No Devices Connected</h3>
                    <p className="text-sm text-stone-500 max-w-md mx-auto">
                        Connect your wearable device to start tracking your health metrics and receive personalized insights
                    </p>
                </div>
            )}
        </div>
    );
};

export default Devices;
