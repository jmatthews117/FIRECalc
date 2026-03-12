// Updated server.js with limit=2 for accurate daily change calculation
// This fetches 2 days of data (today + yesterday) to calculate change vs. previous close

const express = require('express');
const fetch = require('node-fetch');
require('dotenv').config();
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());

app.get('/', (req, res) => {
    res.json({ status: 'FIRECalc API Proxy Running' });
});

// Single quote endpoint - returns 2 days of data for accurate daily change
app.get('/api/quote/:symbol', async (req, res) => {
    try {
        const symbol = req.params.symbol.toUpperCase();
        const apiKey = process.env.MARKETSTACK_API_KEY;
        
        if (!apiKey) {
            return res.status(500).json({ error: 'API key not configured' });
        }
        
        // Request 2 days of data: today's close + yesterday's close
        const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbol}&limit=2`;
        const response = await fetch(url);
        const data = await response.json();
        
        if (data.error) {
            return res.status(400).json({ error: data.error.message });
        }
        
        // Calculate daily change using yesterday's close as reference
        if (data.data && data.data.length >= 2) {
            const today = data.data[0];
            const yesterday = data.data[1];
            
            // Add calculated change to today's data
            today.previousClose = yesterday.close;
            today.dailyChange = today.close - yesterday.close;
            today.dailyChangePercent = (today.dailyChange / yesterday.close);
            
            console.log(`✅ ${symbol}: $${today.close} (${today.dailyChangePercent >= 0 ? '+' : ''}${(today.dailyChangePercent * 100).toFixed(2)}%)`);
        }
        
        res.json(data);
    } catch (error) {
        console.error('Error fetching quote:', error);
        res.status(500).json({ error: 'Failed to fetch stock quote' });
    }
});

// Batch quotes endpoint - returns 2 days of data for each symbol
app.get('/api/quotes', async (req, res) => {
    try {
        const symbols = req.query.symbols;
        const apiKey = process.env.MARKETSTACK_API_KEY;
        
        if (!apiKey) {
            return res.status(500).json({ error: 'API key not configured' });
        }
        
        if (!symbols) {
            return res.status(400).json({ error: 'symbols parameter required' });
        }
        
        // Request 2 days of data for all symbols
        const url = `http://api.marketstack.com/v1/eod/latest?access_key=${apiKey}&symbols=${symbols}&limit=2`;
        const response = await fetch(url);
        const data = await response.json();
        
        if (data.error) {
            return res.status(400).json({ error: data.error.message });
        }
        
        // Group quotes by symbol and calculate daily change
        if (data.data && data.data.length > 0) {
            const quotesBySymbol = {};
            
            // Group by symbol
            data.data.forEach(quote => {
                if (!quotesBySymbol[quote.symbol]) {
                    quotesBySymbol[quote.symbol] = [];
                }
                quotesBySymbol[quote.symbol].push(quote);
            });
            
            // Calculate daily change for each symbol
            const processedQuotes = [];
            Object.keys(quotesBySymbol).forEach(symbol => {
                const quotes = quotesBySymbol[symbol];
                
                // Sort by date descending (most recent first)
                quotes.sort((a, b) => new Date(b.date) - new Date(a.date));
                
                const today = quotes[0];
                
                if (quotes.length >= 2) {
                    const yesterday = quotes[1];
                    
                    // Add calculated change to today's data
                    today.previousClose = yesterday.close;
                    today.dailyChange = today.close - yesterday.close;
                    today.dailyChangePercent = (today.dailyChange / yesterday.close);
                }
                
                processedQuotes.push(today);
            });
            
            // Replace data array with processed quotes
            data.data = processedQuotes;
            
            console.log(`✅ Processed ${processedQuotes.length} symbols with daily changes`);
        }
        
        res.json(data);
    } catch (error) {
        console.error('Error fetching quotes:', error);
        res.status(500).json({ error: 'Failed to fetch stock quotes' });
    }
});

app.listen(PORT, () => {
    console.log(`🚀 FIRECalc API Proxy running on port ${PORT}`);
    console.log(`📊 Using limit=2 for accurate daily change calculation`);
});
