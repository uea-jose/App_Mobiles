############################################################
# ESSENZA API TEST - INVENTARIO PERFUMES
# Prueba completa del backend usando PowerShell
############################################################


############################################################
# 1) LOGIN ADMIN
# Obtiene el token JWT necesario para acceder a la API
############################################################

$resp = Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:3000/api/auth/login" `
  -ContentType "application/json" `
  -Body (@{
    username="admin"
    password="admin"
  } | ConvertTo-Json)

# guardar token
$token = $resp.token

# mostrar token
$token



############################################################
# 2) CREAR UNA BRAND (CASA PERFUMERA)
# Ejemplo: Dior
############################################################

Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:3000/api/brands" `
  -Headers @{ Authorization="Bearer $token" } `
  -ContentType "application/json" `
  -Body (@{
    name="Dior"
    country="France"
  } | ConvertTo-Json)



############################################################
# 3) LISTAR TODAS LAS BRANDS
############################################################

$brands = Invoke-RestMethod `
  -Method Get `
  -Uri "http://localhost:3000/api/brands" `
  -Headers @{ Authorization="Bearer $token" }

# mostrar lista
$brands.brands



############################################################
# 4) OBTENER EL ID DE LA BRAND
# necesario para crear productos
############################################################

$brandId = $brands.brands[0].id

# mostrar el brandId
$brandId



############################################################
# 5) CREAR UN PERFUME (PRODUCTO)
############################################################

Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:3000/api/products" `
  -Headers @{ Authorization="Bearer $token" } `
  -ContentType "application/json" `
  -Body (@{

    name="Sauvage"
    brandId=$brandId
    gender="MASCULINO"
    description="Eau de parfum intenso"
    price=120
    imageUrl="https://example.com/sauvage.png"

    # inventario inicial
    stock=10
    minStock=2

  } | ConvertTo-Json)



############################################################
# 6) LISTAR PRODUCTOS
############################################################

Invoke-RestMethod `
  -Method Get `
  -Uri "http://localhost:3000/api/products" `
  -Headers @{ Authorization="Bearer $token" }



############################################################
# 7) ACTUALIZAR INVENTARIO
############################################################

# obtener producto
$product = (Invoke-RestMethod `
  -Method Get `
  -Uri "http://localhost:3000/api/products" `
  -Headers @{ Authorization="Bearer $token" }).products[0]

$productId = $product.id

# actualizar stock
Invoke-RestMethod `
  -Method Put `
  -Uri "http://localhost:3000/api/inventory/$productId" `
  -Headers @{ Authorization="Bearer $token" } `
  -ContentType "application/json" `
  -Body (@{
    stock=20
    minStock=5
  } | ConvertTo-Json)



############################################################
# 8) ACTUALIZAR PRODUCTO
############################################################

Invoke-RestMethod `
  -Method Put `
  -Uri "http://localhost:3000/api/products/$productId" `
  -Headers @{ Authorization="Bearer $token" } `
  -ContentType "application/json" `
  -Body (@{

    name="Sauvage Dior"
    brandId=$brandId
    gender="MASCULINO"
    description="Versión actualizada"
    price=135
    imageUrl="https://example.com/sauvage2.png"
    isActive=$true

  } | ConvertTo-Json)



############################################################
# 9) ELIMINAR PRODUCTO
############################################################

Invoke-RestMethod `
  -Method Delete `
  -Uri "http://localhost:3000/api/products/$productId" `
  -Headers @{ Authorization="Bearer $token" }



############################################################
# FIN
############################################################