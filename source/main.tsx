import React from 'react';
import {createRoot} from 'react-dom/client';
import Club from './app/club';
import './app/globals.css';
createRoot(document.getElementById('root')!).render(<React.StrictMode><Club/></React.StrictMode>);
