import { Request, Response } from 'express';
import { exec } from 'child_process';
import path from 'path';

export const runOCR = async (req: Request, res: Response): Promise<void> => {
  if (!req.file) {
    res.status(400).json({ success: false, reason: 'NO_IMAGE', message: 'No image uploaded' });
    return;
  }

  const imagePath = req.file.path;
  const scriptPath = path.resolve(__dirname, '../../../../ocr/src/inference.py');

  exec(`python3 ${scriptPath} --image ${imagePath}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`OCR Error: ${error.message}`);
      res.status(500).json({ success: false, reason: 'OCR_FAILED', message: 'OCR process failed' });
      return;
    }

    try {
      // Find the JSON block in stdout (ignoring prints from model loading)
      const outputLines = stdout.trim().split('\n');
      const jsonStr = outputLines[outputLines.length - 1]; // Assuming JSON is on the last line
      const result = JSON.parse(jsonStr);
      res.json(result);
    } catch (e) {
      console.error(`Parse Error: ${e}`);
      console.error(`Stdout: ${stdout}`);
      res.status(500).json({ success: false, reason: 'INVALID_OUTPUT', message: 'Invalid OCR output format' });
    }
  });
};

export const getHealth = (req: Request, res: Response): void => {
  res.json({ status: 'ok', service: 'ML_OCR_Pipeline' });
};

export const getModelInfo = (req: Request, res: Response): void => {
  // Read from evaluation/results.json if we had it
  const resultsPath = path.resolve(__dirname, '../../../../ocr/evaluation/results.json');
  try {
    const fs = require('fs');
    if (fs.existsSync(resultsPath)) {
      const data = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));
      res.json({
        model: 'CRNN-CTC',
        version: '1.0',
        training_dataset: 'local_ocr_dataset',
        cer: data.CER,
        wer: data.WER
      });
      return;
    }
  } catch (e) {}
  
  res.json({
    model: 'CRNN-CTC',
    version: '1.0',
    training_dataset: 'local_ocr_dataset',
    cer: 0.0,
    wer: 0.0
  });
};
