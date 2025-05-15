# Travel App API Documentation

This document describes the REST API endpoints for the Travel App backend, which provides PostgreSQL database access for projects, invoices, and image processing.

## Authentication

All API endpoints require authentication using Firebase Auth. Include the Firebase ID token in the Authorization header:

```
Authorization: Bearer <firebase-id-token>
```

## Projects

### List Projects

Retrieves all projects for the authenticated user.

- **URL**: `/api/projects`
- **Method**: `GET`
- **Auth required**: Yes
- **Response**: 
  ```json
  [
    {
      "id": "uuid",
      "user_id": "firebase-uid",
      "title": "Project Title",
      "description": "Project Description",
      "location": "New York",
      "start_date": "2023-06-01T00:00:00Z",
      "end_date": "2023-06-07T00:00:00Z",
      "budget": 500.00,
      "is_completed": false,
      "created_at": "2023-05-15T12:00:00Z",
      "updated_at": "2023-05-15T12:00:00Z"
    }
  ]
  ```

### Get Project

Retrieves a specific project by ID.

- **URL**: `/api/projects/:projectId`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**: `projectId=[uuid]`
- **Response**: 
  ```json
  {
    "id": "uuid",
    "user_id": "firebase-uid",
    "title": "Project Title",
    "description": "Project Description",
    "location": "New York",
    "start_date": "2023-06-01T00:00:00Z",
    "end_date": "2023-06-07T00:00:00Z",
    "budget": 500.00,
    "is_completed": false,
    "created_at": "2023-05-15T12:00:00Z",
    "updated_at": "2023-05-15T12:00:00Z"
  }
  ```

### Create Project

Creates a new project.

- **URL**: `/api/projects`
- **Method**: `POST`
- **Auth required**: Yes
- **Data**:
  ```json
  {
    "title": "Project Title",
    "description": "Project Description",
    "location": "New York",
    "start_date": "2023-06-01T00:00:00Z",
    "end_date": "2023-06-07T00:00:00Z",
    "budget": 500.00,
    "is_completed": false
  }
  ```
- **Response**: 
  ```json
  {
    "id": "uuid",
    "user_id": "firebase-uid",
    "title": "Project Title",
    "description": "Project Description",
    "location": "New York",
    "start_date": "2023-06-01T00:00:00Z",
    "end_date": "2023-06-07T00:00:00Z",
    "budget": 500.00,
    "is_completed": false,
    "created_at": "2023-05-15T12:00:00Z",
    "updated_at": "2023-05-15T12:00:00Z"
  }
  ```

### Update Project

Updates an existing project.

- **URL**: `/api/projects/:projectId`
- **Method**: `PATCH`
- **Auth required**: Yes
- **URL Params**: `projectId=[uuid]`
- **Data**:
  ```json
  {
    "title": "Updated Project Title",
    "description": "Updated Project Description",
    "location": "Los Angeles",
    "start_date": "2023-06-15T00:00:00Z",
    "end_date": "2023-06-22T00:00:00Z",
    "budget": 750.00,
    "is_completed": true
  }
  ```
- **Response**: 
  ```json
  {
    "id": "uuid",
    "user_id": "firebase-uid",
    "title": "Updated Project Title",
    "description": "Updated Project Description",
    "location": "Los Angeles",
    "start_date": "2023-06-15T00:00:00Z",
    "end_date": "2023-06-22T00:00:00Z",
    "budget": 750.00,
    "is_completed": true,
    "created_at": "2023-05-15T12:00:00Z",
    "updated_at": "2023-05-16T09:30:00Z"
  }
  ```

### Delete Project

Deletes a project.

- **URL**: `/api/projects/:projectId`
- **Method**: `DELETE`
- **Auth required**: Yes
- **URL Params**: `projectId=[uuid]`
- **Response**: 
  - Status: 204 No Content

## Project Images

### List Project Images

Retrieves all images for a project.

- **URL**: `/api/projects/:projectId/images`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**: `projectId=[uuid]`
- **Response**: 
  ```json
  [
    {
      "id": "image-id",
      "invoiceId": "invoice-uuid",
      "projectId": "project-uuid",
      "userId": "firebase-uid",
      "status": "uploaded",
      "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
      "isInvoiceGuess": true,
      "invoiceAnalysis": {
        "merchant_name": "Acme Inc",
        "totalAmount": 125.99,
        "date": "2023-06-05T00:00:00Z",
        "currency": "USD"
      },
      "invoiceDate": "2023-06-05T00:00:00Z",
      "uploadedAt": "2023-06-10T14:30:00Z",
      "createdAt": "2023-06-10T14:30:00Z",
      "updatedAt": "2023-06-10T15:45:00Z"
    }
  ]
  ```

## Invoice Images

### List Invoice Images

Retrieves all images for an invoice.

- **URL**: `/api/projects/:projectId/invoices/:invoiceId/images`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**: 
  - `projectId=[uuid]`
  - `invoiceId=[uuid]`
- **Response**: 
  ```json
  [
    {
      "id": "image-id",
      "invoiceId": "invoice-uuid",
      "projectId": "project-uuid",
      "userId": "firebase-uid",
      "status": "uploaded",
      "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
      "isInvoiceGuess": true,
      "invoiceAnalysis": {
        "merchant_name": "Acme Inc",
        "totalAmount": 125.99,
        "date": "2023-06-05T00:00:00Z",
        "currency": "USD"
      },
      "invoiceDate": "2023-06-05T00:00:00Z",
      "uploadedAt": "2023-06-10T14:30:00Z",
      "createdAt": "2023-06-10T14:30:00Z",
      "updatedAt": "2023-06-10T15:45:00Z"
    }
  ]
  ```

### Get Invoice Image

Retrieves a specific image.

- **URL**: `/api/projects/:projectId/invoices/:invoiceId/images/:imageId`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**: 
  - `projectId=[uuid]`
  - `invoiceId=[uuid]`
  - `imageId=[string]`
- **Response**: 
  ```json
  {
    "id": "image-id",
    "invoiceId": "invoice-uuid",
    "projectId": "project-uuid",
    "userId": "firebase-uid",
    "status": "uploaded",
    "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
    "isInvoiceGuess": true,
    "invoiceAnalysis": {
      "merchant_name": "Acme Inc",
      "totalAmount": 125.99,
      "date": "2023-06-05T00:00:00Z",
      "currency": "USD"
    },
    "invoiceDate": "2023-06-05T00:00:00Z",
    "uploadedAt": "2023-06-10T14:30:00Z",
    "createdAt": "2023-06-10T14:30:00Z",
    "updatedAt": "2023-06-10T15:45:00Z"
  }
  ```

### Upload Invoice Image

Uploads a new image for an invoice.

- **URL**: `/api/projects/:projectId/invoices/:invoiceId/images`
- **Method**: `POST`
- **Auth required**: Yes
- **URL Params**: 
  - `projectId=[uuid]`
  - `invoiceId=[uuid]`
- **Content-Type**: `multipart/form-data` or `application/json`
- **Form Data**:
  - `image`: The image file

  OR 

- **JSON Data**:
  ```json
  {
    "id": "image-id",
    "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
    "status": "uploaded"
  }
  ```

  OR

- **JSON Data with Base64**:
  ```json
  {
    "image": "base64-encoded-image-data",
    "fileName": "image.jpg"
  }
  ```
- **Response**: 
  ```json
  {
    "id": "image-id",
    "invoiceId": "invoice-uuid",
    "projectId": "project-uuid",
    "userId": "firebase-uid",
    "status": "uploaded",
    "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
    "isInvoiceGuess": null,
    "invoiceAnalysis": {},
    "invoiceDate": null,
    "uploadedAt": "2023-06-10T14:30:00Z",
    "createdAt": "2023-06-10T14:30:00Z",
    "updatedAt": "2023-06-10T14:30:00Z"
  }
  ```

### Delete Invoice Image

Deletes an image.

- **URL**: `/api/projects/:projectId/invoices/:invoiceId/images/:imageId`
- **Method**: `DELETE`
- **Auth required**: Yes
- **URL Params**: 
  - `projectId=[uuid]`
  - `invoiceId=[uuid]`
  - `imageId=[string]`
- **Response**: 
  - Status: 204 No Content

### Update OCR Results

Updates OCR results for an image.

- **URL**: `/api/projects/:projectId/invoices/:invoiceId/images/:imageId/ocr`
- **Method**: `PATCH`
- **Auth required**: Yes
- **URL Params**: 
  - `projectId=[uuid]`
  - `invoiceId=[uuid]`
  - `imageId=[string]`
- **Data**:
  ```json
  {
    "isInvoiceGuess": true,
    "invoiceAnalysis": {
      "text": "Invoice #12345\nMerchant: Acme Inc\nAmount: $125.99\nDate: 2023-06-05"
    },
    "lastProcessedAt": "2023-06-10T15:45:00Z"
  }
  ```
- **Response**: 
  ```json
  {
    "id": "image-id",
    "invoiceId": "invoice-uuid",
    "projectId": "project-uuid",
    "userId": "firebase-uid",
    "status": "uploaded",
    "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
    "isInvoiceGuess": true,
    "invoiceAnalysis": {
      "text": "Invoice #12345\nMerchant: Acme Inc\nAmount: $125.99\nDate: 2023-06-05"
    },
    "invoiceDate": null,
    "uploadedAt": "2023-06-10T14:30:00Z",
    "createdAt": "2023-06-10T14:30:00Z",
    "updatedAt": "2023-06-10T15:45:00Z"
  }
  ```

### Update Analysis Details

Updates analysis details for an image.

- **URL**: `/api/projects/:projectId/invoices/:invoiceId/images/:imageId/analysis`
- **Method**: `PATCH`
- **Auth required**: Yes
- **URL Params**: 
  - `projectId=[uuid]`
  - `invoiceId=[uuid]`
  - `imageId=[string]`
- **Data**:
  ```json
  {
    "invoiceAnalysis": {
      "merchant_name": "Acme Inc",
      "merchant_location": "New York, NY",
      "totalAmount": 125.99,
      "tax": 10.50,
      "currency": "USD",
      "date": "2023-06-05T00:00:00Z",
      "category": "Office Supplies"
    },
    "isInvoiceGuess": true,
    "status": "analysis_complete_invoice",
    "lastProcessedAt": "2023-06-10T15:45:00Z",
    "invoiceDate": "2023-06-05T00:00:00Z"
  }
  ```
- **Response**: 
  ```json
  {
    "id": "image-id",
    "invoiceId": "invoice-uuid",
    "projectId": "project-uuid",
    "userId": "firebase-uid",
    "status": "analysis_complete_invoice",
    "imagePath": "users/uid/projects/pid/invoices/iid/invoice_images/filename.jpg",
    "isInvoiceGuess": true,
    "invoiceAnalysis": {
      "merchant_name": "Acme Inc",
      "merchant_location": "New York, NY",
      "totalAmount": 125.99,
      "tax": 10.50,
      "currency": "USD",
      "date": "2023-06-05T00:00:00Z",
      "category": "Office Supplies"
    },
    "invoiceDate": "2023-06-05T00:00:00Z",
    "uploadedAt": "2023-06-10T14:30:00Z",
    "createdAt": "2023-06-10T14:30:00Z",
    "updatedAt": "2023-06-10T15:45:00Z"
  }
  ```

## Error Responses

All endpoints will return appropriate HTTP status codes:

- `400 Bad Request`: Invalid parameters or data
- `401 Unauthorized`: Missing or invalid authentication token
- `403 Forbidden`: User doesn't have permission to access the resource
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server-side error

Error response format:

```json
{
  "error": "Error message"
}
``` 