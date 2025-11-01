# ---- Stage 1: Build ----
# Sử dụng image node đầy đủ để build
FROM node:20-alpine as builder

WORKDIR /app

# Copy package.json và package-lock.json
COPY package*.json ./

# Cài đặt dependencies
RUN npm install

# Copy toàn bộ mã nguồn
COPY . .

# Build ứng dụng
RUN npm run build

# ---- Stage 2: Production ----
# Sử dụng image alpine nhẹ hơn để chạy
FROM node:20-alpine

WORKDIR /app

# Chỉ copy những file cần thiết từ stage 'builder'
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3000

# Lệnh chạy ứng dụng production
CMD ["npm", "run", "start:prod"]