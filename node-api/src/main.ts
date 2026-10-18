import 'reflect-metadata';
import { ConsoleLogger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';

const production = process.env.NODE_ENV === 'production';

const app = await NestFactory.create(AppModule, {
  // JSON lines in production (easy to ship to Loki & co.), pretty in dev
  logger: new ConsoleLogger({ json: production, colors: !production }),
});

app.setGlobalPrefix('api/v1', { exclude: ['health'] });
app.useGlobalPipes(
  new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
);
// Close the pg pool and Redis connection on SIGTERM (docker stop)
app.enableShutdownHooks();

await app.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
