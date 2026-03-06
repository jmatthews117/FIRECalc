// server.js
// FIRECalc Backend Proxy for Marketstack API
// Keeps API key secure on server, provides HTTPS endpoint for iOS app

const express = require('express');
const fetch = require('node-fetch');
require('dotenv').config();
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3000;

// ==================== MIDDLEWARE ====================

// Enable CORS for mobile apps
app.use(cors());

// Rate limiting to prevent abuse
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per 15 minutes
    message: { error: 'Too many requests, please try again later' }
});

app.use('/api/', limiter);

// Request logging
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`${timestamp} - ${req.method} ${req.path}`);
    next();
});

// ==================== CONFIGURATION ====================

const MARKETSTACK_API_KEY = process.env.MARKETSTACK_API_KEY;
const MARKETSTACK_BASE_URL = 'http://api.marketstack.com/v1';

// Validate configuration on startup
if (!MARKETSTACK_API_KEY) {
    console.error('❌ FATAL: MARKETSTACK_API_KEY environment variable not set!');
    console.error('Please set it in your .env file or hosting platform');
    process.exit(1);
}

// ==================== ROUTES ====================

// Health check endpoint
app.get('/', (req, res) => {
    res.json({ 
        status: 'online',
        service: 'FIRECalc API Proxy',
        version: '1.0.0',
        endpoints: [
            'GET /api/quote/:symbol',
            'GET /api/quotes?symbols=AAPL,MSFT,...'
        ]
    });
});

// Single stock quote endpoint
app.get('/api/quote/:symbol', async (req, res) => {
    try {
        const symbol = req.params.symbol.toUpperCase().trim();
        
        // Validate symbol
        if (!symbol || symbol.length === 0) {
            return res.status(400).json({ 
                error: 'Invalid symbol parameter' 
            });
        }
        
        console.log(`📡 Fetching quote for ${symbol}`);
        
        // Build Marketstack API URL
        const url = `${MARKETSTACK_BASE_URL}/eod/latest?access_key=${MARKETSTACK_API_KEY}&symbols=${symbol}&limit=1`;
        
        // Fetch from Marketstack
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Accept': 'application/json'
            },
            timeout: 10000 // 10 second timeout
        });
        
        const data = await response.json();
        
        // Handle Marketstack API errors
        if (data.error) {
            console.error(`❌ Marketstack API error: ${data.error.message}`);
            return res.status(400).json({ 
                error: data.error.message,
                code: data.error.code 
            });
        }
        
        // Check if we got data
        if (!data.data || data.data.length === 0) {
            console.warn(`⚠️ No data found for ${symbol}`);
            return res.status(404).json({ 
                error: `No quote data available for symbol ${symbol}`,
                symbol: symbol
            });
        }
        
        console.log(`✅ Successfully fetched quote for ${symbol}`);
        
        // Return the Marketstack response
        res.json(data);
        
    } catch (error) {
        console.error('❌ Error fetching quote:', error.message);
        
        // Handle specific error types
        if (error.name === 'FetchError') {
            return res.status(503).json({ 
                error: 'Marketstack API unavailable',
                message: 'Please try again later'
            });
        }
        
        res.status(500).json({ 
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Batch quotes endpoint
app.get('/api/quotes', async (req, res) => {
    try {
        const symbols = req.query.symbols;
        
        // Validate symbols parameter
        if (!symbols || symbols.trim().length === 0) {
            return res.status(400).json({ 
                error: 'Missing symbols parameter',
                example: '/api/quotes?symbols=AAPL,MSFT,GOOGL'
            });
        }
        
        const symbolList = symbols.split(',').map(s => s.trim().toUpperCase()).join(',');
        
        console.log(`📡 Fetching batch quotes for: ${symbolList}`);
        
        // Build Marketstack API URL
        const url = `${MARKETSTACK_BASE_URL}/eod/latest?access_key=${MARKETSTACK_API_KEY}&symbols=${symbolList}`;
        
        // Fetch from Marketstack
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Accept': 'application/json'
            },
            timeout: 15000 // 15 second timeout for batch
        });
        
        const data = await response.json();
        
        // Handle Marketstack API errors
        if (data.error) {
            console.error(`❌ Marketstack API error: ${data.error.message}`);
            return res.status(400).json({ 
                error: data.error.message,
                code: data.error.code 
            });
        }
        
        const count = data.data?.length || 0;
        console.log(`✅ Successfully fetched ${count} quotes`);
        
        // Return the Marketstack response
        res.json(data);
        
    } catch (error) {
        console.error('❌ Error fetching batch quotes:', error.message);
        
        if (error.name === 'FetchError') {
            return res.status(503).json({ 
                error: 'Marketstack API unavailable',
                message: 'Please try again later'
            });
        }
        
        res.status(500).json({ 
            error: 'Internal server error',
            message: error.message
        });
    }
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ 
        error: 'Endpoint not found',
        availableEndpoints: [
            'GET /',
            'GET /api/quote/:symbol',
            'GET /api/quotes?symbols=AAPL,MSFT'
        ]
    });
});

// ==================== START SERVER ====================

app.listen(PORT, () => {
    console.log('='.repeat(50));
    console.log('🚀 FIRECalc API Proxy Server Started');
    console.log('='.repeat(50));
    console.log(`📍 Port: ${PORT}`);
    console.log(`🔗 Local: http://localhost:${PORT}`);
    console.log(`🔐 API Key: ${MARKETSTACK_API_KEY ? '✅ Configured' : '❌ Missing'}`);
    console.log('='.repeat(50));
    console.log('📡 Available Endpoints:');
    console.log(`   GET  /                    - Health check`);
    console.log(`   GET  /api/quote/:symbol   - Single quote`);
    console.log(`   GET  /api/quotes?symbols= - Batch quotes`);
    console.log('='.repeat(50));
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('👋 SIGTERM received, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('👋 SIGINT received, shutting down gracefully...');
    process.exit(0);
});
