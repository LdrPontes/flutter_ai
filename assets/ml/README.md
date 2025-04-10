# ML Models Directory

This directory contains the machine learning models used by the application.

## Required Models

Place the following models in this directory:

1. `birds.tflite` - The TensorFlow Lite model for bird detection
2. `labels.txt` - Text file containing bird species labels for the model

## Model Requirements

- The model should be in TensorFlow Lite format (.tflite)
- The model should be optimized for mobile deployment
- Input size should match the requirements specified in the model loading code
- Labels file should contain one bird species name per line

## Usage

The models in this directory are automatically loaded by the application when needed. Make sure to:

1. Place the correct model files in this directory
2. Update the model loading code if the model architecture changes
3. Test the model with sample bird images before deployment

## Notes

- Keep model files as small as possible to minimize app size
- Consider using model quantization for better performance
- Test model performance on target devices
- Ensure the model is trained on a diverse dataset of bird species 