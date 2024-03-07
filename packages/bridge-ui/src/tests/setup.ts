import dotenv from 'dotenv';

dotenv.config({ path: './.env.test' });

vi.mock('@wagmi/core');
