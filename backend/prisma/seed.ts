import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Seed medical categories
  const categories = [
    { name: 'Blood Test', description: 'Blood test reports including CBC, metabolic panels, etc.', icon: '🩸' },
    { name: 'Prescription', description: 'Doctor prescriptions and medication orders', icon: '💊' },
    { name: 'Scan Report', description: 'X-ray, MRI, CT scan, ultrasound reports', icon: '📷' },
    { name: 'Discharge Summary', description: 'Hospital discharge summaries', icon: '🏥' },
    { name: 'Medical Bill', description: 'Medical bills and insurance documents', icon: '💰' },
    { name: 'Lab Report', description: 'Laboratory test results', icon: '🔬' },
    { name: 'General', description: 'General medical documents', icon: '📋' },
    { name: 'Other', description: 'Other or non-medical documents', icon: '📁' },
  ];

  for (const cat of categories) {
    await prisma.medicalCategory.upsert({
      where: { name: cat.name },
      update: {},
      create: cat,
    });
  }
  console.log(`Seeded ${categories.length} medical categories`);

  // Seed health parameters
  const healthParams = [
    { name: 'glucose', displayName: 'Blood Glucose', defaultUnit: 'mg/dL', description: 'Blood sugar level', normalMin: 70, normalMax: 100 },
    { name: 'hemoglobin', displayName: 'Hemoglobin', defaultUnit: 'g/dL', description: 'Hemoglobin concentration', normalMin: 12, normalMax: 17.5 },
    { name: 'systolic_bp', displayName: 'Systolic Blood Pressure', defaultUnit: 'mmHg', description: 'Systolic blood pressure', normalMin: 90, normalMax: 120 },
    { name: 'diastolic_bp', displayName: 'Diastolic Blood Pressure', defaultUnit: 'mmHg', description: 'Diastolic blood pressure', normalMin: 60, normalMax: 80 },
    { name: 'cholesterol', displayName: 'Total Cholesterol', defaultUnit: 'mg/dL', description: 'Total cholesterol level', normalMin: 0, normalMax: 200 },
    { name: 'heart_rate', displayName: 'Heart Rate', defaultUnit: 'bpm', description: 'Heart rate / pulse', normalMin: 60, normalMax: 100 },
    { name: 'hba1c', displayName: 'HbA1c', defaultUnit: '%', description: 'Glycated hemoglobin', normalMin: 4, normalMax: 5.6 },
    { name: 'creatinine', displayName: 'Creatinine', defaultUnit: 'mg/dL', description: 'Blood creatinine level', normalMin: 0.7, normalMax: 1.3 },
    { name: 'wbc', displayName: 'White Blood Cells', defaultUnit: 'cells/mcL', description: 'White blood cell count', normalMin: 4500, normalMax: 11000 },
    { name: 'platelets', displayName: 'Platelets', defaultUnit: 'cells/mcL', description: 'Platelet count', normalMin: 150000, normalMax: 400000 },
  ];

  for (const param of healthParams) {
    await prisma.healthParameter.upsert({
      where: { name: param.name },
      update: {},
      create: param,
    });
  }
  console.log(`Seeded ${healthParams.length} health parameters`);

  console.log('Database seeding completed!');
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
