<?php
/**
 * ==============================================================================
 * phpMyAdmin Multi-Store Database Administration Configuration
 * 
 * CRITICAL ARCHITECTURAL SECURITY RULE:
 * ------------------------------------------------------------------------------
 * phpMyAdmin must be used ONLY as a visual database administration tool.
 * Application credentials, API keys, AWS credentials, and store admin passwords
 * must NEVER be stored inside custom phpMyAdmin tables or plaintext DB columns!
 * 
 * CREDENTIAL VAULT LOCATIONS:
 * - Local Development:   .env (from .env.example)
 * - Kubernetes:          Kubernetes Secrets
 * - AWS Production:      AWS Secrets Manager (KMS encrypted)
 * ==============================================================================
 */

// Enable advanced features
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['MaxRows'] = 100;
$cfg['SendErrorReports'] = 'never';

// --- Server 1: Default / Main Magento Store Database ---
$i = 1;
$cfg['Servers'][$i]['verbose'] = 'Store 1: Main Retail Store (magento2)';
$cfg['Servers'][$i]['host'] = getenv('PMA_HOST') ?: 'mysql';
$cfg['Servers'][$i]['port'] = getenv('PMA_PORT') ?: '3306';
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['user'] = getenv('PMA_USER') ?: 'magento';
$cfg['Servers'][$i]['only_db'] = ['magento2', 'magento2_b2b', 'magento2_eu'];
$cfg['Servers'][$i]['AllowNoPassword'] = false;
$cfg['Servers'][$i]['compress'] = false;

// --- Server 2: B2B Wholesale Store Database (Isolated Replica/DB) ---
$i++;
$cfg['Servers'][$i]['verbose'] = 'Store 2: B2B Wholesale Store';
$cfg['Servers'][$i]['host'] = getenv('PMA_HOST') ?: 'mysql';
$cfg['Servers'][$i]['port'] = getenv('PMA_PORT') ?: '3306';
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['user'] = getenv('PMA_USER') ?: 'magento';
$cfg['Servers'][$i]['only_db'] = ['magento2_b2b'];
$cfg['Servers'][$i]['AllowNoPassword'] = false;

// --- Server 3: International EU Store Database ---
$i++;
$cfg['Servers'][$i]['verbose'] = 'Store 3: EU International Store';
$cfg['Servers'][$i]['host'] = getenv('PMA_HOST') ?: 'mysql';
$cfg['Servers'][$i]['port'] = getenv('PMA_PORT') ?: '3306';
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['user'] = getenv('PMA_USER') ?: 'magento';
$cfg['Servers'][$i]['only_db'] = ['magento2_eu'];
$cfg['Servers'][$i]['AllowNoPassword'] = false;
