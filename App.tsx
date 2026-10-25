import React from 'react';
import { HashRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import { AdminProvider } from './contexts/AdminContext';
import { SidebarProvider } from './contexts/SidebarContext';
import { UserProvider } from './contexts/UserContext';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import Home from './pages/Home';
import Protocol from './pages/Protocol';
import HealthData from './pages/HealthData';
import FoodIntelligence from './pages/FoodIntelligence';

import Devices from './pages/Devices';
import Intelligence from './pages/Intelligence';
import HealthDomains from './pages/HealthDomains';
import DiseaseRiskAnalysis from './pages/DiseaseRiskAnalysis';
import Chat from './pages/Chat';
import Tools from './pages/Tools';
import Settings from './pages/Settings';
import Login from './pages/Login';
import Signup from './pages/Signup';
import HealthQuestionnaire from './pages/HealthQuestionnaire';
import LabTestUpload from './pages/LabTestUpload';
import AdminLayout from './components/AdminLayout';
import AdminDashboard from './pages/admin/AdminDashboard';
import CreatePatient from './pages/admin/CreatePatient';
import PatientDetail from './pages/admin/PatientDetail';
import NutritionWorkbench from './pages/admin/NutritionWorkbench';
import NutritionLab from './pages/admin/NutritionLab';
import AdminLogin from './pages/admin/AdminLogin';
import HealthVault from './pages/HealthVault';
import GutMicrobiomeDetail from './pages/panels/GutMicrobiomeDetail';
import GeneticPanelDetail from './pages/panels/GeneticPanelDetail';
import BiologicalAgeDetail from './pages/panels/BiologicalAgeDetail';
import HeavyMetalsDetail from './pages/panels/HeavyMetalsDetail';
import ToxicityDetail from './pages/panels/ToxicityDetail';

// Placeholder for missing pages
const Profile = () => <div className="p-8">Profile Page Coming Soon</div>;

const App: React.FC = () => {
  return (
    <ErrorBoundary>
      <Router>
        <AuthProvider>
          <AdminProvider>
            <SidebarProvider>
              <Routes>
                {/* Public Routes */}
                <Route path="/login" element={<Login />} />
                <Route path="/signup" element={<Signup />} />

                {/* Admin Login - Separate from regular login */}
                <Route path="/admin/login" element={<AdminLogin />} />

                {/* Admin Portal Routes - Protected */}
                <Route
                  path="/admin"
                  element={
                    <ProtectedRoute requireAdmin>
                      <AdminLayout />
                    </ProtectedRoute>
                  }
                >
                  <Route index element={<AdminDashboard />} />
                  <Route path="patients/create" element={<CreatePatient />} />
                  <Route path="patient/:id" element={<PatientDetail />} />
                  <Route path="nutrition" element={<NutritionWorkbench />} />
                  <Route path="nutrition-lab" element={<NutritionLab />} />
                </Route>

                {/* User Portal Routes - Protected */}
                <Route
                  path="/"
                  element={
                    <ProtectedRoute>
                      <UserProvider>
                        <Layout />
                      </UserProvider>
                    </ProtectedRoute>
                  }
                >
                  <Route index element={<Home />} />
                  <Route path="health-data" element={<HealthData />} />
                  <Route path="intelligence" element={<Intelligence />} />
                  <Route path="intelligence/domains" element={<HealthDomains />} />
                  <Route path="intelligence/risks" element={<DiseaseRiskAnalysis />} />

                  <Route path="protocol" element={<Protocol />} />
                  <Route path="devices" element={<Devices />} />
                  <Route path="tools" element={<Tools />} />
                  <Route path="settings" element={<Settings />} />
                  <Route path="chat" element={<Chat />} />
                  <Route path="profile" element={<Profile />} />
                  <Route path="questionnaire" element={<HealthQuestionnaire />} />
                  <Route path="lab-test" element={<LabTestUpload />} />
                  <Route path="food-intelligence" element={<FoodIntelligence />} />
                  <Route path="health-vault" element={<HealthVault />} />
                  <Route path="health-vault/gut-microbiome" element={<GutMicrobiomeDetail />} />
                  <Route path="health-vault/genetic" element={<GeneticPanelDetail />} />
                  <Route path="health-vault/biological-age" element={<BiologicalAgeDetail />} />
                  <Route path="health-vault/heavy-metals" element={<HeavyMetalsDetail />} />
                  <Route path="health-vault/toxicity" element={<ToxicityDetail />} />
                </Route>

                {/* Catch all - redirect to home */}
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </SidebarProvider>
          </AdminProvider>
        </AuthProvider>
      </Router>
    </ErrorBoundary>
  );
};

export default App;